defmodule Funkspector.Resolver do
  @moduledoc """
  Provides a method to follow URL redirections, returning the final URL.
  """

  @doc """
  Given a URL, it will follow the redirections and return the final URL and the final response.

  ## Examples

      iex> { :ok, final_url, _response } = Funkspector.Resolver.resolve("http://github.com")
      iex> final_url
      "https://github.com/"
  """
  def resolve(url, max_redirects \\ 5, response \\ %{})
  def resolve(url, max_redirects, response) when max_redirects < 1, do: {:ok, url, response}
  def resolve(url, max_redirects, _response) do
    # SSL cert verification disabled until this bug is solved:
    # https://github.com/edgurgel/httpoison/issues/93
    #
    # Also, we set the SSL version to fix this:
    # http://campezzi.ghost.io/httpoison-ssl-connection-closed/
    case HTTPoison.get(url, [], hackney: [:insecure], ssl: [versions: [:"tlsv1.2"]]) do
      { :ok, response = %{ status_code: status, headers: headers } } when status in 300..399 ->
        to = URI.merge(url, location_from(headers)) |> to_string
        resolve(to, max_redirects - 1, deflated(response))
      { :ok, response = %{ status_code: status } } when (status < 200) or (status >= 400) ->
        { :error, url, deflated(response) }
      { :error, url, response } ->
        { :error, url, deflated(response) }
      { status, response } ->
        { status, url, deflated(response) }
    end
  end

  defp location_from(headers) do
    Enum.into(headers, %{})["Location"] || Enum.into(headers, %{})["location"]
  end

  # Deflates the body if it was gzip-compressed. Temporary until HTTPoison handles this:
  # https://github.com/edgurgel/httpoison/issues/81
  #
  defp deflated(response) do
    gzipped = Map.has_key?(response, :headers) && Enum.any?(response.headers, fn(kv) ->
      case kv do
        { "Content-Encoding", "gzip" } -> true
        _ -> false
      end
    end)

    if gzipped do
      Map.put response, :body, :zlib.gunzip(response.body)
    else
      response
    end
  end
end
