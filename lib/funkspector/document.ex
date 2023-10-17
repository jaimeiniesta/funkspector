defmodule Funkspector.Document do
  @moduledoc """
  Defines the Document struct and functions to request or load its body.
  """

  defstruct [:url, :body, :data]

  alias __MODULE__
  alias Funkspector.Resolver

  @doc """
  Retrieves the url and returns a document with its body.
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
  Returns a document with the given body and optional root_url.

  Options:

    - `:url` allows to set an URL for the document, which is useful later on for parsing and setting absolute links.
  """
  def load(body, options \\ %{}) do
    url = options[:url]

    {:ok, %Document{body: body, url: url}}
  end

  #####################
  # Private functions #
  #####################

  defp handle_response(response = %{status_code: status, body: _body}, original_url, _final_url)
       when status not in 200..299 do
    {:error, original_url, response}
  end

  defp handle_response(
         %{status_code: status, headers: headers, body: body},
         original_url,
         final_url
       )
       when status in 200..299 do
    {:ok,
     %Document{
       url: final_url,
       body: body,
       data: %{
         original_url: original_url,
         headers: Enum.into(headers, %{})
       }
     }}
  end
end
