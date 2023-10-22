defmodule Funkspector.SitemapScraper do
  @moduledoc """
  Scrapes an XML sitemap.
  """

  import Funkspector.Utils
  import SweetXml

  alias Funkspector.Document

  @doc """
  Scrapes the Document contents and returns the data scraped from its XML.
  """
  def scrape(%Document{} = document) do
    {:ok, %{document | data: scraped_data(document)}}
  end

  #####################
  # Private functions #
  #####################

  defp scraped_data(%Document{url: url, contents: contents, data: data}) do
    locs = contents |> raw_locs() |> absolutify(url)

    Map.put_new(data || %{}, :locs, locs)
  end

  defp raw_locs(xml) do
    try do
      xml
      |> parse(quiet: true)
      |> xpath(~x"//url/loc/text()"l)
      |> Enum.uniq()
      |> Enum.map(&to_string/1)
    catch
      _, _ -> []
    end
  end
end
