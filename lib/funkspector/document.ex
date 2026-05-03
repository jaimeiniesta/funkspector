defmodule Funkspector.Document do
  @moduledoc """
  Defines the Document struct and functions to request or load its contents.

  A Document holds the final URL, the raw contents (HTML, XML, or text),
  and a `data` map populated by the scrapers with extracted information.
  """

  @type t :: %__MODULE__{
          url: String.t() | nil,
          contents: String.t() | nil,
          data: map() | nil
        }

  defstruct [:url, :contents, :data]

  alias __MODULE__
  alias Funkspector.Resolver

  import Funkspector.Utils, only: [valid_url?: 1]

  @doc """
  Retrieves the URL contents via HTTP and returns a Document.

  Follows redirects (via `Funkspector.Resolver`) and returns the final URL
  along with the response body and headers. Returns an error tuple if the
  URL is invalid, the host cannot be resolved, or the response status is not 2xx.
  """
  @spec request(String.t(), map()) ::
          {:ok, t()} | {:error, String.t() | any(), any()}
  def request(url, options \\ %{}) do
    case Resolver.resolve(url, options) do
      {:ok, final_url, response} ->
        handle_response(response, url, final_url)

      {_, url, response} ->
        {:error, url, response}
    end
  end

  @doc """
  Creates a Document from pre-fetched contents without making an HTTP request.

  Useful when the content has already been retrieved or for testing.
  Returns an error if the URL is not valid.
  """
  @spec load(String.t(), String.t()) ::
          {:ok, t()} | {:error, String.t() | any(), :invalid_url}
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
