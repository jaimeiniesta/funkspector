defmodule Funkspector.Resolver do
  @moduledoc """
  Provides a method to follow URL redirections, returning the final URL.
  """

  # In case of these errors related with SSL we'll retry setting a TLS version, as per this post:
  # http://campezzi.ghost.io/httpoison-ssl-connection-closed/
  @reasons_to_retry_with_ssl_version [
    %HTTPoison.Error{id: nil, reason: :closed},
    %HTTPoison.Error{id: nil, reason: {:tls_alert, 'handshake failure'}},
    %HTTPoison.Error{
      id: nil,
      reason: {:options, {:sslv3, {:versions, [:"tlsv1.2", :"tlsv1.1", :tlsv1, :sslv3]}}}
    },
    %HTTPoison.Error{
      id: nil,
      reason:
        {:tls_alert,
         {:handshake_failure,
          'TLS client: In state hello received SERVER ALERT: Fatal - Handshake Failure\\n'}}
    }
  ]

  @doc """
  Given a URL, it will follow the redirections and return the final URL and the final response.

  ## Examples

      iex> { :ok, final_url, _response } = Funkspector.Resolver.resolve("http://github.com")
      iex> final_url
      "https://github.com/"
  """
  def resolve(url, options \\ %{}) do
    resolve_url(url, 5, %{}, options)
  end

  #####################
  # Private functions #
  #####################

  defp resolve_url(url, max_redirects, response, _options) when max_redirects < 1,
    do: {:ok, url, response}

  defp resolve_url(url, max_redirects, _response, options) do
    # SSL cert verification disabled until this bug is solved:
    # https://github.com/edgurgel/httpoison/issues/93
    case HTTPoison.get(url, ["User-Agent": user_agent(options)], Map.to_list(options)) do
      {:ok, response = %{status_code: status, headers: headers}} when status in 300..399 ->
        to = URI.merge(url, location_from(headers)) |> to_string
        resolve_url(to, max_redirects - 1, deflated(response), options)

      {:ok, response = %{status_code: status}} when status < 200 or status >= 400 ->
        {:error, url, deflated(response)}

      {:error, response} when response in @reasons_to_retry_with_ssl_version ->
        if is_nil(options[:ssl]) do
          resolve_url(
            url,
            max_redirects - 1,
            response,
            Map.merge(%{ssl: [versions: [:"tlsv1.2"]]}, options)
          )
        else
          {:error, url, deflated(response)}
        end

      {status, response} ->
        {status, url, deflated(response)}
    end
  end

  #####################
  # Private functions #
  #####################

  defp location_from(headers) do
    Enum.into(headers, %{})["Location"] || Enum.into(headers, %{})["location"]
  end

  # Deflates the body if it was gzip-compressed. Temporary until HTTPoison handles this:
  # https://github.com/edgurgel/httpoison/issues/81
  #
  defp deflated(response) do
    gzipped =
      Map.has_key?(response, :headers) &&
        Enum.any?(response.headers, fn kv ->
          case kv do
            {"Content-Encoding", "gzip"} -> true
            {"Content-Encoding", "x-gzip"} -> true
            _ -> false
          end
        end)

    if gzipped do
      Map.put(response, :body, :zlib.gunzip(response.body))
    else
      response
    end
  end

  # Provides a browser-like user agent
  defp user_agent(options) do
    options[:user_agent]
  end
end
