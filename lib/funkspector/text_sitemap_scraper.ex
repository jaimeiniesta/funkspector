defmodule Funkspector.TextSitemapScraper do
  @moduledoc """
  Scrapes a text sitemap.
  """

  import Funkspector.Utils

  alias Funkspector.Document

  @doc """
  Scrapes the Document contents and returns the data scraped from the text lines.
  """
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
