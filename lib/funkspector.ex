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

  ## HTTP adapter

  The actual HTTP transport is pluggable. Funkspector ships with two
  adapters and defaults to the Req one:

    * `Funkspector.HTTP.Adapters.Req` (default) — Finch/Mint, no hackney.
    * `Funkspector.HTTP.Adapters.HTTPoison` — opt-in, wraps the historical
      HTTPoison/hackney 1.21 stack.

  Select an adapter globally through application config:

      # config/config.exs
      config :funkspector, :http_adapter, Funkspector.HTTP.Adapters.HTTPoison

  Or per call by passing the `:adapter` option:

      Funkspector.resolve(url, %{adapter: Funkspector.HTTP.Adapters.HTTPoison})
  """

  alias Funkspector.{Resolver, Document, PageScraper, SitemapScraper, TextSitemapScraper}
  alias Funkspector.{Response, Error}

  @typedoc """
  Why a `resolve`/`scrape` call failed: a non-2xx `Funkspector.Response`, a
  transport `Funkspector.Error`, or one of the validation/limit atoms.
  """
  @type error_reason ::
          Response.t()
          | Error.t()
          | :invalid_url
          | :invalid_contents
          | :too_many_redirects

  @doc """
  Follows redirections for the given URL, returning the final URL and response.

  ## Examples

      iex> { :ok, final_url, _response } = Funkspector.resolve("http://github.com")
      iex> final_url
      "https://github.com/"
  """
  @spec resolve(String.t() | any(), map()) ::
          {:ok, String.t(), Response.t()} | {:error, String.t() | any(), error_reason()}
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

      iex> {:error, "https://notfoundwebsite.com", %Funkspector.Error{reason: :nxdomain}} =
      ...>   Funkspector.page_scrape("https://notfoundwebsite.com")
  """
  @spec page_scrape(String.t() | any(), map()) ::
          {:ok, Document.t()} | {:error, String.t() | any(), error_reason()}
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
  @spec sitemap_scrape(String.t() | any(), map()) ::
          {:ok, Document.t()} | {:error, String.t() | any(), error_reason()}
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
  @spec text_sitemap_scrape(String.t() | any(), map()) ::
          {:ok, Document.t()} | {:error, String.t() | any(), error_reason()}
  def text_sitemap_scrape(url, options \\ %{}) do
    scrape(url, options, &TextSitemapScraper.scrape/1)
  end

  #####################
  # Private functions #
  #####################

  defp default_options do
    %{
      # TLS certificate verification is ON by default. Pass `insecure: true`
      # to disable it for hosts with broken/self-signed certificates; both
      # adapters honor the flag (see `Funkspector.HTTP.Adapter`).
      insecure: false,
      timeout: 28_000,
      recv_timeout: 25_000,
      # Upper bound on both the raw response body and the gunzipped output, to
      # bound memory when scraping untrusted URLs (decompression is hard-capped;
      # the raw body is checked after receipt). Set `:infinity` to disable.
      max_body_size: 100_000_000,
      user_agent: "Funkspector/#{version()} (+https://hex.pm/packages/funkspector)"
    }
  end

  # Read from the compiled app spec so the User-Agent tracks the mix.exs
  # version instead of duplicating it.
  defp version, do: Application.spec(:funkspector, :vsn) |> to_string()

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
      _ -> {:error, url, :invalid_contents}
    end
  end
end
