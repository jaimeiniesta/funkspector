defmodule Funkspector.PageScraper do
  @moduledoc """
  Provides a method to scrape an HTML page, given its URL.
  """

  import Funkspector.Utils

  alias Funkspector.Document

  @doc """
  Scrapes the Document contents and returns the data scraped from its HTML.
  """
  def scrape(%Document{} = document) do
    {:ok, %{document | data: scraped_data(document)}}
  end

  #####################
  # Private functions #
  #####################

  defp scraped_data(%Document{url: url, contents: contents, data: data}) do
    %{scheme: scheme, host: host} = URI.parse(url)

    urls =
      (data[:urls] || %{})
      |> Map.put_new(:root_url, "#{scheme}://#{host}/")
      |> Map.put_new(:base_url, base_href(contents, url) || url)

    raw_links = raw_links(contents)

    {http_links, non_http_links} =
      raw_links
      |> absolutify(urls.base_url)
      |> http_and_non_http

    {internal_links, external_links} = internal_and_external(http_links, host)

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
    |> Map.put_new(:scheme, scheme)
    |> Map.put_new(:host, host)
    |> Map.put_new(:links, links)
  end

  defp base_href(html, url) do
    case html
         |> Floki.parse_document!()
         |> Floki.find("base")
         |> Floki.attribute("href")
         |> List.first() do
      nil -> nil
      base_href -> absolutify(base_href, url)
    end
  end

  defp raw_links(html) do
    html
    |> Floki.parse_document!()
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

  defp same_host?(link, host) do
    case URI.parse(link) do
      %{host: ^host} -> true
      _ -> false
    end
  end
end
