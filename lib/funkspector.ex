defmodule Funkspector do
  @moduledoc """
  A web scraper that extracts data from HTML pages, XML sitemaps, and text sitemaps.

  Provides four public functions:

    * `resolve/2` - follows URL redirections and returns the final URL
    * `page_scrape/2` - parses an HTML page and extracts links
    * `sitemap_scrape/2` - parses an XML sitemap and extracts URLs
    * `text_sitemap_scrape/2` - parses a text sitemap and extracts URLs

  All scrape functions accept an optional `contents:` keyword in the options
  map to skip the HTTP request and scrape pre-fetched content instead.
  """

  alias Funkspector.{Resolver, Document, PageScraper, SitemapScraper, TextSitemapScraper}

  @doc """
  Follows redirections for the given URL, returning the final URL and response.

  ## Examples

      iex> { :ok, final_url, _response } = Funkspector.resolve("http://github.com")
      iex> final_url
      "https://github.com/"
  """
  @spec resolve(String.t(), map()) ::
          {:ok, String.t(), map()} | {:error, String.t() | any(), any()}
  def resolve(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    Resolver.resolve(url, options)
  end

  @doc """
  Parses an HTML document, extracting links and metadata.

  Makes an HTTP request to the URL (following redirects), then parses the HTML
  to extract internal/external links, raw links, non-HTTP links, canonical URL,
  and base href.

  Pass `contents:` in the options map to scrape pre-fetched HTML instead:

      Funkspector.page_scrape("https://example.com", %{contents: "<html>...</html>"})

  ## Example: request a document

      iex> { :ok, document } = Funkspector.page_scrape("https://jaimeiniesta.com")
      iex> Enum.take(document.data.links.http.external, 3)
      ["http://www.archive.elixirconf.eu/elixirconf2016", "https://steadyhq.com/", "https://stuart.com/"]

  ## Example: site not found

      iex> Funkspector.page_scrape("https://notfoundwebsite.com")
      {:error, "https://notfoundwebsite.com", %HTTPoison.Error{reason: :nxdomain, id: nil}}
  """
  @spec page_scrape(String.t(), map()) ::
          {:ok, Document.t()} | {:error, String.t() | any(), any()}
  def page_scrape(url, options \\ %{}) do
    scrape(url, options, &PageScraper.scrape/1)
  end

  @doc """
  Parses an XML sitemap, extracting the list of URLs.

  Makes an HTTP request to the URL, then parses the XML to extract all
  `<loc>` elements from `<url>` entries.

  Pass `contents:` in the options map to scrape pre-fetched XML instead:

      Funkspector.sitemap_scrape("https://example.com/sitemap.xml", %{contents: "<xml>...</xml>"})

  ## Example

      iex> { :ok, document } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.xml")
      iex> length(document.data.locs) > 0
      true
      iex> hd(document.data.locs)
      "https://rocketvalidator.com/"
  """
  @spec sitemap_scrape(String.t(), map()) ::
          {:ok, Document.t()} | {:error, String.t() | any(), any()}
  def sitemap_scrape(url, options \\ %{}) do
    scrape(url, options, &SitemapScraper.scrape/1)
  end

  @doc """
  Parses a plain text sitemap, extracting the list of URLs.

  Makes an HTTP request to the URL, then splits the text by newlines to
  extract one URL per line.

  Pass `contents:` in the options map to scrape pre-fetched text instead:

      Funkspector.text_sitemap_scrape("https://example.com/sitemap.txt", %{contents: "..."})

  ## Example

      iex> { :ok, document } = Funkspector.text_sitemap_scrape("https://rocketvalidator.com/sitemap.txt")
      iex> length(document.data.lines) > 0
      true
      iex> hd(document.data.lines)
      "https://rocketvalidator.com/"
  """
  @spec text_sitemap_scrape(String.t(), map()) ::
          {:ok, Document.t()} | {:error, String.t() | any(), any()}
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

  defp scrape(url, options, scraping_function) do
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
