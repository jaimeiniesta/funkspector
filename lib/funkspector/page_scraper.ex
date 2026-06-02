defmodule Funkspector.PageScraper do
  @moduledoc """
  Extracts links and metadata from an HTML page.

  Parses the HTML to find all `<a href>` links, then classifies them as
  internal/external HTTP links or non-HTTP links (mailto, javascript, ftp, etc.).
  Also extracts the `<base href>` and `<link rel="canonical">` values.

  > #### Not a security boundary {: .warning}
  > `links.http.internal`/`links.http.external` is a host-string comparison
  > against the final fetched document host, and relative links are resolved
  > against the page's own `<base href>`. A scraped page can therefore steer
  > where its relative links point. Re-validate any URL (and apply your own
  > SSRF/egress controls) before fetching it — do not treat "internal" as
  > "same-origin and safe".
  """

  import Funkspector.Utils

  alias Funkspector.Document

  @doc """
  Scrapes the Document contents and returns the data extracted from its HTML.

  Populates the document's `data` map with:

    * `urls.base` - the base URL (from `<base href>` or the document URL)
    * `urls.canonical` - the canonical URL if present, otherwise `nil`
    * `links.raw` - all raw `href` values found in `<a>` tags (deduplicated)
    * `links.http.internal` - absolute HTTP links matching the document's host
    * `links.http.external` - absolute HTTP links to other hosts
    * `links.non_http` - non-HTTP links (mailto, javascript, ftp, etc.)
  """
  @spec scrape(Document.t()) :: {:ok, Document.t()}
  def scrape(%Document{} = document) do
    {:ok, %{document | data: scraped_data(document)}}
  end

  #####################
  # Private functions #
  #####################

  defp scraped_data(%Document{url: url, contents: contents, data: data}) do
    # Parse the HTML once and reuse the tree; a nil body (possible from the
    # HTTPoison adapter for body-less responses) is treated as empty rather
    # than crashing `Floki.parse_document!/1`.
    doc = Floki.parse_document!(contents || "")

    urls =
      (data[:urls] || %{})
      |> Map.put_new(:base, base_href(doc, url) || url)

    # The canonical URL is resolved against the (possibly <base href>-derived)
    # base, consistent with how <a> links are resolved and with the HTML spec.
    urls = Map.put_new(urls, :canonical, canonical_url(doc, urls.base))

    raw_links = raw_links(doc)

    {http_links, non_http_links} =
      raw_links
      |> absolutify(urls.base)
      |> http_and_non_http

    {internal_links, external_links} = internal_and_external(http_links, urls[:parsed].host)

    links = %{
      raw: raw_links,
      http: %{
        internal: internal_links,
        external: external_links
      },
      non_http: non_http_links
    }

    (data || %{})
    |> Map.put(:urls, urls)
    |> Map.put_new(:links, links)
  end

  defp canonical_url(doc, base) do
    case doc
         |> Floki.find("link[rel=canonical]")
         |> Floki.attribute("href")
         |> List.first() do
      nil -> nil
      canonical_href -> absolutify(canonical_href, base)
    end
  end

  defp base_href(doc, url) do
    case doc
         |> Floki.find("base")
         |> Floki.attribute("href")
         |> List.first() do
      nil -> nil
      base_href -> absolutify(base_href, url)
    end
  end

  defp raw_links(doc) do
    doc
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.map(&String.trim/1)
    |> Enum.uniq()
  end

  defp http_and_non_http(links) do
    Enum.split_with(links, &(&1 =~ ~r/^http(s)?:\/\//i))
  end

  defp internal_and_external(links, host) do
    Enum.split_with(links, &same_host?(&1, host))
  end

  # Host names are case-insensitive (RFC 3986), so compare them downcased.
  defp same_host?(link, host) do
    case URI.parse(link) do
      %{host: link_host} when is_binary(link_host) and is_binary(host) ->
        String.downcase(link_host) == String.downcase(host)

      _ ->
        false
    end
  end
end
