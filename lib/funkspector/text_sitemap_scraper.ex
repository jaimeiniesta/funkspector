defmodule Funkspector.TextSitemapScraper do
  @moduledoc """
  Provides a method to scrape a text sitemap, given its URL.
  """

  import Funkspector, only: [default_options: 0]
  import Funkspector.Utils
  alias Funkspector.Resolver

  @doc """
  Fetches the given URL, follows redirections, and returns the data scraped from the text lines.
  """
  def scrape(original_url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    case Resolver.resolve(original_url, options) do
      {:ok, final_url, response} ->
        handle_response(response, original_url, final_url)

      {_, url, response} ->
        {:error, url, response}
    end
  end

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
    {:ok, scraped_data(headers, body, original_url, final_url)}
  end

  defp scraped_data(headers, body, original_url, final_url) do
    %{scheme: scheme, host: host} = URI.parse(final_url)

    root_url = "#{scheme}://#{host}/"
    lines = raw_lines(body) |> absolutify(root_url)

    %{
      scheme: scheme,
      host: host,
      original_url: original_url,
      final_url: final_url,
      root_url: root_url,
      headers: Enum.into(headers, %{}),
      body: body,
      lines: lines
    }
  end

  defp raw_lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end
end
