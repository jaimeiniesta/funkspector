defmodule Funkspector.Resolver do
  def resolve(url, max_redirects \\ 5, response \\ %{})
  def resolve(url, max_redirects, response) when max_redirects < 1, do: {:ok, url, response}
  def resolve(url, max_redirects, _response) do
    case HTTPoison.get(url) do
      {:ok, response = %{status_code: status, headers: headers}} when status in 300..399 ->
        to = Enum.into(headers, %{})["Location"]
        resolve(to, max_redirects - 1, response)
      {:ok, response = %{status_code: status}} when (status < 200) or (status >= 400) ->
        {:error, url, response}
      {:error, url, response} ->
        {:error, url, response}
      {status, response} ->
        {status, url, response}
    end
  end
end
