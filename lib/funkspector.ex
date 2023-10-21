defmodule Funkspector do
  @moduledoc """
  Funkspector is a web scraper that lets you extract data from web pages.
  """

  alias Funkspector.{Document, PageScraper, SitemapScraper}

  @doc """
  Parses an HTML document.

  This can be used to request a document by passing its URL, like:

    Funkspector.page_scrape("https://jaimeiniesta.com")

  Or to scrape an already loaded document, by passing its HTML contents and base URL

    Funkspector.page_scrape("https://example.com", contents: "<html>...</html>")

  ## Example: requesting and scraping a document

      iex> { :ok, document } = Funkspector.page_scrape("https://jaimeiniesta.com")
      iex> Enum.take(document.data.links.http.external, 3)
      ["http://www.archive.elixirconf.eu/elixirconf2016", "https://steadyhq.com/", "https://stuart.com/"]
  """
  def page_scrape(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    with {:ok, document} <- request_or_load_contents(url, options),
         {:ok, document} <- PageScraper.scrape(document) do
      {:ok, document}
    else
      error -> error
    end
  end

  @doc """
  Parses an XML sitemap.

  ## Examples

      iex> { :ok, document } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.xml")
      iex> length document.data.locs
      1238
      iex> Enum.take(document.data.locs, 3)
      ["https://rocketvalidator.com/", "https://rocketvalidator.com/pricing?billing=weekly", "https://rocketvalidator.com/pricing?billing=monthly"]
  """
  def sitemap_scrape(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    with {:ok, document} <- request_or_load_contents(url, options),
         {:ok, document} <- SitemapScraper.scrape(document) do
      {:ok, document}
    else
      error -> error
    end
  end

  @doc """
  Convenience method, this is just a shortcut for `Funkspector.TextSitemapScraper.scrape/1`.

  ## Examples

      iex> { :ok, data } = Funkspector.text_sitemap_scrape("https://rocketvalidator.com/sitemap.txt")
      iex> length data.lines
      1238
      iex> [ first | _ ] = data.lines
      iex> first
      "https://rocketvalidator.com/"
  """
  def text_sitemap_scrape(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    Funkspector.TextSitemapScraper.scrape(url, options)
  end

  def default_options do
    %{
      hackney: [:insecure],
      timeout: 28_000,
      recv_timeout: 25_000,
      user_agent: "Funkspector/0.6.0 (+https://hex.pm/packages/funkspector)"
    }
  end

  #####################
  # Private functions #
  #####################

  defp request_or_load_contents(url, options) do
    case options[:contents] do
      nil -> Document.request(url, options)
      contents when is_binary(contents) -> Document.load(contents, %{url: url})
    end
  end
end
