defmodule Funkspector.Resolver do
  @moduledoc """
  Follows HTTP redirections and returns the final URL and response.

  Handles up to 5 redirect hops, supports SSL/TLS version fallback
  (retrying with TLSv1.2 on handshake failures), automatic gzip
  decompression, basic authentication, and custom User-Agent headers.

  The actual HTTP transport is delegated to a pluggable adapter — see
  `Funkspector.HTTP.Adapter`. The adapter is selected from
  `opts[:adapter]` or from application config:

      config :funkspector, :http_adapter, Funkspector.HTTP.Adapters.Req
  """

  import Funkspector.Utils, only: [valid_url?: 1]

  alias Funkspector.{Response, Error}

  # TLS handshake failures we retry by pinning the connection to TLSv1.2 — the
  # historical workaround for old servers that fail protocol/cipher
  # negotiation (http://campezzi.ghost.io/httpoison-ssl-connection-closed/).
  #
  # We match the alert *atom* structurally, because each adapter reports a
  # host- and handshake-state-specific message string (Mint/OTP's
  # `:ssl.error_alert()` shape `{:tls_alert, {alert, charlist}}`), so an exact
  # term match would never fire. Certificate-validation alerts
  # (`:bad_certificate`, `:certificate_expired`, `:unknown_ca`, …) are
  # deliberately excluded: a version downgrade cannot fix a bad certificate,
  # and retrying would only mask the rejection.
  @retryable_tls_alerts [
    :handshake_failure,
    :protocol_version,
    :insufficient_security,
    :unrecognized_name
  ]

  @doc """
  Follows redirections for the given URL and returns the final URL and response.

  Validates the URL, then follows up to 5 HTTP redirects (status 301-399).
  Returns an error for invalid URLs, non-2xx final responses, HTTP 300
  (Multiple Choices), a 3xx without a usable `Location` header, and chains
  that exceed the redirect limit (`:too_many_redirects`). On certain SSL
  handshake errors, retries once with TLSv1.2 (without consuming the redirect
  budget). Basic-auth credentials are stripped when a redirect crosses origin.

  ## Options

    * `:basic_auth` - `{username, password}` tuple for HTTP Basic Authentication
    * `:user_agent` - custom User-Agent header string
    * `:ssl` - SSL options forwarded to the adapter
    * `:hackney` - hackney-specific options (honored by the HTTPoison adapter;
      the Req adapter translates the `:insecure` flag and ignores the rest)
    * `:timeout` - connection timeout in milliseconds
    * `:recv_timeout` - receive timeout in milliseconds
    * `:adapter` - override the HTTP adapter for this call

  ## Examples

      iex> { :ok, final_url, _response } = Funkspector.Resolver.resolve("http://github.com")
      iex> final_url
      "https://github.com/"
  """
  @spec resolve(String.t() | any(), map()) ::
          {:ok, String.t(), Response.t()}
          | {:error, String.t() | any(),
             Response.t() | Error.t() | :invalid_url | :too_many_redirects}
  def resolve(url, options \\ %{}) do
    if valid_url?(url) do
      resolve_url(url, 5, options)
    else
      {:error, url, :invalid_url}
    end
  end

  #####################
  # Private functions #
  #####################

  defp resolve_url(url, max_redirects, options) do
    case adapter(options).get(url, options) do
      {:ok, response} ->
        case deflate(response, max_body_size(options)) do
          {:ok, response} -> dispatch(url, response, max_redirects, options)
          :too_large -> {:error, url, :body_too_large}
        end

      {:error, %Error{reason: reason} = error} ->
        # Retry once with TLSv1.2 on a retryable handshake failure. The retry
        # does NOT consume the redirect budget; the `is_nil(options[:ssl])`
        # guard caps it at a single attempt (the merge sets `:ssl`).
        if retry_ssl?(reason) and is_nil(options[:ssl]) do
          resolve_url(url, max_redirects, Map.merge(%{ssl: [versions: [:"tlsv1.2"]]}, options))
        else
          {:error, url, error}
        end
    end
  end

  defp dispatch(
         url,
         %Response{status_code: status, headers: headers} = response,
         max_redirects,
         options
       )
       when status in 301..399 do
    follow_redirect(url, headers, response, max_redirects, options)
  end

  defp dispatch(url, %Response{status_code: 300} = response, _max_redirects, _options) do
    {:error, url, response}
  end

  defp dispatch(url, %Response{status_code: status} = response, _max_redirects, _options)
       when status < 200 or status >= 400 do
    {:error, url, response}
  end

  defp dispatch(url, response, _max_redirects, _options) do
    {:ok, url, response}
  end

  # A 3xx with no usable Location header is treated as a terminal response
  # rather than crashing on `URI.merge(url, nil)`. Once the redirect budget is
  # exhausted we return an explicit `:too_many_redirects` error instead of an
  # `:ok` tuple for a URL we never fetched.
  defp follow_redirect(url, headers, response, max_redirects, options) do
    case followable_location(url, headers) do
      nil ->
        {:error, url, response}

      _to when max_redirects < 1 ->
        {:error, url, :too_many_redirects}

      to ->
        resolve_url(to, max_redirects - 1, redirect_options(url, to, options))
    end
  end

  defp followable_location(url, headers) do
    case location_from(headers) do
      location when is_binary(location) and location != "" ->
        URI.merge(url, location) |> to_string()

      _ ->
        nil
    end
  end

  # Basic auth must not leak to a different origin, so it is stripped when a
  # redirect crosses scheme/host/port.
  defp redirect_options(from_url, to_url, options) do
    if same_origin?(from_url, to_url) do
      options
    else
      Map.delete(options, :basic_auth)
    end
  end

  defp same_origin?(from_url, to_url) do
    a = URI.parse(from_url)
    b = URI.parse(to_url)

    downcase(a.scheme) == downcase(b.scheme) and
      downcase(a.host) == downcase(b.host) and a.port == b.port
  end

  defp downcase(nil), do: nil
  defp downcase(string), do: String.downcase(string)

  defp retry_ssl?(:closed), do: true
  defp retry_ssl?({:tls_alert, {alert, _desc}}), do: alert in @retryable_tls_alerts
  defp retry_ssl?(_), do: false

  defp adapter(options) do
    options[:adapter] ||
      Application.get_env(:funkspector, :http_adapter, Funkspector.HTTP.Adapters.Req)
  end

  # HTTP header field names are case-insensitive, and the two adapters disagree
  # on casing (Req downcases; HTTPoison preserves the server's), so normalize
  # before looking anything up.
  defp location_from(headers) do
    downcased_headers(headers)["location"]
  end

  defp downcased_headers(headers) when is_list(headers) do
    Map.new(headers, fn {name, value} -> {String.downcase(name), value} end)
  end

  defp downcased_headers(_), do: %{}

  # Decompresses a gzip-encoded body, bounded by `limit` so a small "zip bomb"
  # cannot expand to gigabytes. Returns `{:ok, response}` (body possibly
  # inflated) or `:too_large` when the decompressed output would exceed `limit`.
  defp deflate(%Response{headers: headers, body: body} = response, limit) do
    if gzipped?(headers) and is_binary(body) do
      case gunzip_within_limit(body, limit) do
        {:ok, inflated} -> {:ok, %Response{response | body: inflated}}
        :too_large -> :too_large
      end
    else
      {:ok, response}
    end
  end

  defp deflate(response, _limit), do: {:ok, response}

  defp gunzip_within_limit(body, :infinity), do: {:ok, :zlib.gunzip(body)}

  defp gunzip_within_limit(body, limit) when is_integer(limit) do
    z = :zlib.open()

    try do
      :zlib.inflateInit(z, 31)
      safe_inflate(z, body, limit, [], 0)
    after
      :zlib.close(z)
    end
  end

  # Streams the decompressed output in zlib-bounded chunks (via `safeInflate`)
  # so we never materialize more than `limit` bytes before aborting.
  defp safe_inflate(z, input, limit, acc, total) do
    case :zlib.safeInflate(z, input) do
      {:continue, output} ->
        total = total + IO.iodata_length(output)

        if total > limit do
          :too_large
        else
          safe_inflate(z, [], limit, [acc | output], total)
        end

      {:finished, output} ->
        total = total + IO.iodata_length(output)

        if total > limit do
          :too_large
        else
          {:ok, IO.iodata_to_binary([acc | output])}
        end
    end
  end

  defp max_body_size(options), do: options[:max_body_size] || :infinity

  defp gzipped?(headers) when is_list(headers) do
    downcased_headers(headers)["content-encoding"] in ["gzip", "x-gzip"]
  end

  defp gzipped?(_), do: false
end
