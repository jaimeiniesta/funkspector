defmodule Funkspector.TextSitemapScraper do
  @moduledoc """
  Extracts URLs from a plain text sitemap.

  Parses text sitemaps where each line contains a single URL.
  Empty lines and whitespace are stripped, duplicates are removed,
  and relative URLs are converted to absolute.
  """

  import Funkspector.Utils

  alias Funkspector.Document

  @doc """
  Scrapes the Document contents and returns URLs extracted from the text lines.

  Populates the document's `data` map with a `:lines` key containing a
  deduplicated list of absolute URLs, one per non-empty line in the text.
  """
  @spec scrape(Document.t()) :: {:ok, Document.t()}
  def scrape(%Document{} = document) do
    {:ok, %{document | data: scraped_data(document)}}
  end

  defp scraped_data(%Document{url: url, contents: contents, data: data}) do
    lines = contents |> raw_lines() |> absolutify(url)

    Map.put_new(data || %{}, :lines, lines)
  end

  defp raw_lines(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end
end
