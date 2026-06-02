defmodule Funkspector.SitemapScraper do
  @moduledoc """
  Extracts URLs from an XML sitemap.

  Parses XML sitemaps conforming to the sitemaps.org protocol, extracting
  `<loc>` elements from `<url>` entries using XPath. Relative URLs are
  converted to absolute. Gracefully handles malformed XML by returning
  an empty list.
  """

  import Funkspector.Utils
  import SweetXml

  alias Funkspector.Document

  @doc """
  Scrapes the Document contents and returns URLs extracted from the XML sitemap.

  Populates the document's `data` map with a `:locs` key containing a
  deduplicated list of absolute URLs found in `//url/loc` elements.
  Returns an empty list if the XML cannot be parsed.
  """
  @spec scrape(Document.t()) :: {:ok, Document.t()}
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
    # `dtd: :none` makes SweetXml/xmerl refuse all DTD and entity declarations,
    # so an attacker-controlled sitemap cannot trigger XXE (external entity /
    # file read), entity-expansion DoS ("billion laughs"), or an external-DTD
    # fetch — independent of the consumer's OTP/xmerl version. The catch keeps a
    # malformed (or DTD-bearing) sitemap returning `[]` rather than crashing.
    try do
      xml
      |> parse(quiet: true, dtd: :none)
      |> xpath(~x"//url/loc/text()"l)
      |> Enum.uniq()
      |> Enum.map(&to_string/1)
    catch
      _, _ -> []
    end
  end
end
