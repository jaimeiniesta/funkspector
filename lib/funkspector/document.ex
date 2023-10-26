defmodule Funkspector.Document do
  @moduledoc """
  Defines the Document struct and functions to request or load its contents.
  """

  defstruct [:url, :contents, :data]

  alias __MODULE__
  alias Funkspector.Resolver

  import Funkspector.Utils, only: [valid_url?: 1]

  @doc """
  Retrieves the url and returns a document with its contents.
  """
  def request(url, options \\ %{}) do
    case Resolver.resolve(url, options) do
      {:ok, final_url, response} ->
        handle_response(response, url, final_url)

      {_, url, response} ->
        {:error, url, response}
    end
  end

  @doc """
  Returns a document with the given url and contents.
  """
  def load(url, contents) do
    if valid_url?(url) do
      data = %{urls: parsed_url(url)}

      {:ok, %Document{contents: contents, url: url, data: data}}
    else
      {:error, url, :invalid_url}
    end
  end

  #####################
  # Private functions #
  #####################

  defp handle_response(
         response = %{status_code: status, body: _body},
         original_url,
         _final_url
       )
       when status not in 200..299 do
    {:error, original_url, response}
  end

  defp handle_response(
         %{status_code: status, headers: headers, body: body},
         original_url,
         final_url
       )
       when status in 200..299 do
    urls = Map.merge(%{original: original_url}, parsed_url(final_url))

    data = %{urls: urls, headers: Enum.into(headers, %{})}

    {:ok,
     %Document{
       url: final_url,
       contents: body,
       data: data
     }}
  end

  defp parsed_url(url) do
    parsed = url |> URI.parse() |> Map.from_struct()
    root = "#{parsed.scheme}://#{parsed.host}/"

    %{parsed: parsed, root: root}
  end
end
