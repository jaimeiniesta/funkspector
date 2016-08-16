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
    case HTTPoison.get(url) do
      {:ok, response = %{status_code: status, headers: headers}} when status in 300..399 ->
        to = URI.merge(url, location_from(headers)) |> to_string
        resolve(to, max_redirects - 1, response)
      {:ok, response = %{status_code: status}} when (status < 200) or (status >= 400) ->
        {:error, url, response}
      {:error, url, response} ->
        {:error, url, response}
      {status, response} ->
        {status, url, response}
    end
  end

  defp location_from(headers) do
    Enum.into(headers, %{})["Location"] || Enum.into(headers, %{})["location"]
  end
end
