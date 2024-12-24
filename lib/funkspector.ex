defmodule Funkspector do
  @moduledoc """
  Funkspector is a web scraper that lets you extract data from web pages.
  """

  alias Funkspector.{Resolver, Document, PageScraper, SitemapScraper, TextSitemapScraper}

  @doc """
  Given a URL, it will follow the redirections and return the final URL and the final response.

  ## Examples

      iex> { :ok, final_url, _response } = Funkspector.resolve("http://github.com")
      iex> final_url
      "https://github.com/"
  """
  def resolve(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    Resolver.resolve(url, options)
  end

  @doc """
  Parses an HTML document.

  This can be used to request a document by passing its URL, like:

    Funkspector.page_scrape("https://example.com")

  Or to scrape an already loaded document, by passing its HTML contents:

    Funkspector.page_scrape("https://example.com", contents: "<html>...</html>")

  ## Example: request a document

      iex> { :ok, document } = Funkspector.page_scrape("https://jaimeiniesta.com")
      iex> Enum.take(document.data.links.http.external, 3)
      ["http://www.archive.elixirconf.eu/elixirconf2016", "https://steadyhq.com/", "https://stuart.com/"]

  ## Example: site not found

      iex> Funkspector.page_scrape("https://notfoundwebsite.com")
      {:error, "https://notfoundwebsite.com", %HTTPoison.Error{reason: :nxdomain, id: nil}}
  """
  def page_scrape(url, options \\ %{}) do
    scrape(url, options, &PageScraper.scrape/1)
  end

  @doc """
  Parses an XML sitemap.

  This can be used to request a document by passing its URL, like:

    Funkspector.sitemap_scrape("https://example.com")

  Or to scrape an already loaded document, by passing its XML contents:

    Funkspector.sitemap_scrape("https://example.com/sitemap.xml", contents: "<xml>...</xml>")

  ## Example

      iex> { :ok, document } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.xml")
      iex> length document.data.locs
      1749
      iex> Enum.take(document.data.locs, 3)
      ["https://rocketvalidator.com/", "https://rocketvalidator.com/html-validation", "https://rocketvalidator.com/accessibility-validation"]
  """
  def sitemap_scrape(url, options \\ %{}) do
    scrape(url, options, &SitemapScraper.scrape/1)
  end

  @doc """
  Parses a text sitemap.

  This can be used to request a document by passing its URL, like:

    Funkspector.text_sitemap_scrape("https://example.com")

  Or to scrape an already loaded document, by passing its text contents:

    Funkspector.text_sitemap_scrape("https://example.com/sitemap.txt", contents: "...")

  ## Example

      iex> { :ok, document } = Funkspector.text_sitemap_scrape("https://rocketvalidator.com/sitemap.txt")
      iex> length document.data.lines
      1749
      iex> Enum.take(document.data.lines, 3)
      ["https://rocketvalidator.com/", "https://rocketvalidator.com/html-validation", "https://rocketvalidator.com/accessibility-validation"]
  """
  def text_sitemap_scrape(url, options \\ %{}) do
    scrape(url, options, &TextSitemapScraper.scrape/1)
  end

  #####################
  # Private functions #
  #####################

  defp default_options do
    %{
      hackney: [:insecure],
      timeout: 28_000,
      recv_timeout: 25_000,
      user_agent: "Funkspector/0.6.0 (+https://hex.pm/packages/funkspector)"
    }
  end

  def scrape(url, options, scraping_function) do
    options = Map.merge(default_options(), options)

    case request_or_load_contents(url, options) do
      {:ok, document} -> scraping_function.(document)
      error -> error
    end
  end

  defp request_or_load_contents(url, options) do
    case options[:contents] do
      nil -> Document.request(url, options)
      contents when is_binary(contents) -> Document.load(url, contents)
    end
  end
end
