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

  # In case of these errors related with SSL we'll retry setting a TLS version, as per this post:
  # http://campezzi.ghost.io/httpoison-ssl-connection-closed/
  #
  # The match is on the normalized `%Funkspector.Error{}` reason atoms.
  # Each adapter is responsible for mapping its native error onto these
  # atoms (`gen_tcp`/`inet` vocabulary).
  @ssl_retry_reasons [
    :closed,
    {:tls_alert, ~c"handshake failure"},
    {:options, {:sslv3, {:versions, [:"tlsv1.2", :"tlsv1.1", :tlsv1, :sslv3]}}},
    {:tls_alert,
     {:handshake_failure,
      ~c"TLS client: In state hello received SERVER ALERT: Fatal - Handshake Failure\\n"}}
  ]

  @doc """
  Follows redirections for the given URL and returns the final URL and response.

  Validates the URL, then follows up to 5 HTTP redirects (status 301-399).
  Returns an error for invalid URLs, non-2xx final responses, and HTTP 300
  (Multiple Choices). On certain SSL errors, retries with TLSv1.2.

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
          | {:error, String.t() | any(), Response.t() | Error.t() | :invalid_url}
  def resolve(url, options \\ %{}) do
    if valid_url?(url) do
      resolve_url(url, 5, %{}, options)
    else
      {:error, url, :invalid_url}
    end
  end

  #####################
  # Private functions #
  #####################

  defp resolve_url(url, max_redirects, response, _options) when max_redirects < 1,
    do: {:ok, url, response}

  defp resolve_url(url, max_redirects, _response, options) do
    case adapter(options).get(url, options) do
      {:ok, response = %Response{status_code: status, headers: headers}}
      when status in 301..399 ->
        to = URI.merge(url, location_from(headers)) |> to_string
        resolve_url(to, max_redirects - 1, deflated(response), options)

      {:ok, response = %Response{status_code: 300}} ->
        {:error, url, deflated(response)}

      {:ok, response = %Response{status_code: status}} when status < 200 or status >= 400 ->
        {:error, url, deflated(response)}

      {:ok, response} ->
        {:ok, url, deflated(response)}

      {:error, %Error{reason: reason} = error} ->
        if retry_ssl?(reason) and is_nil(options[:ssl]) do
          resolve_url(
            url,
            max_redirects - 1,
            error,
            Map.merge(%{ssl: [versions: [:"tlsv1.2"]]}, options)
          )
        else
          {:error, url, error}
        end
    end
  end

  defp retry_ssl?(reason), do: reason in @ssl_retry_reasons

  defp adapter(options) do
    options[:adapter] ||
      Application.get_env(:funkspector, :http_adapter, Funkspector.HTTP.Adapters.Req)
  end

  defp location_from(headers) do
    map = Enum.into(headers, %{})
    map["Location"] || map["location"]
  end

  # Deflates the body if it was gzip-compressed. Operates on a normalized
  # `%Funkspector.Response{}` produced by the adapter, but accepts any map
  # exposing `:headers` and `:body` so existing tests that pass plain maps
  # keep working.
  defp deflated(%Response{} = response) do
    if gzipped?(response.headers) and is_binary(response.body) do
      %Response{response | body: :zlib.gunzip(response.body)}
    else
      response
    end
  end

  defp deflated(response) when is_map(response) do
    headers = Map.get(response, :headers, [])
    body = Map.get(response, :body)

    if gzipped?(headers) and is_binary(body) do
      Map.put(response, :body, :zlib.gunzip(body))
    else
      response
    end
  end

  defp deflated(other), do: other

  defp gzipped?(headers) when is_list(headers) do
    Enum.any?(headers, fn
      {"Content-Encoding", "gzip"} -> true
      {"Content-Encoding", "x-gzip"} -> true
      {"content-encoding", "gzip"} -> true
      {"content-encoding", "x-gzip"} -> true
      _ -> false
    end)
  end

  defp gzipped?(_), do: false
end
