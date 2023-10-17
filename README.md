# Funkspector

[![Hex.pm](https://img.shields.io/hexpm/v/funkspector.svg?style=flat-square)](https://hex.pm/packages/funkspector)

Web page inspector for Elixir.

Funkspector is a web scraper that lets you extract data from web pages and XML sitemaps.

## Usage

### Page Scraping

Simply pass Funkspector the URL of a web page to inspect and it will return its scraped data:

```elixir
iex> { :ok, data } = Funkspector.page_scrape("https://rocketvalidator.com")
```

### Sitemap Scraping

Funkspector can extract the locations from XML sitemaps, like this:

```elixir
iex> { :ok, data } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.xml")
```

It also supports TXT sitemaps:

```elixir
iex> { :ok, data } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.txt")
```
### Custom options

Both `Funkspector.page_scrape` and `Funkspector.sitemap_scrape` accept options to customize the timeout and User Agent string.

For example, you could use:

```elixir
  Funkspector.page_scrape("http://github.com", %{recv_timeout: 5_000, user_agent: "My Bot"})
  Funkspector.sitemap_scrape("http://validationhell.com/sitemap.xml", %{recv_timeout: 5_000, user_agent: "My Bot"})
```

### Scraped data

Currently Funkspector returns this scraped data both from pages and sitemaps:

* `headers`. Response headers, including content-type etc.
* `body`. Raw body.
* `original_url` and `final_url`. Funkspector follows redirections, here are the original URL given and the final one after following the redirections.
* `scheme`. Like, "http" or "https".
* `host`. Like, "github.com".
* `root_url`. Root url for the given URL. For `http://example.com/about` it will be `http://example.com`.

The PageScraper also returns:

* `links`. Organized in `raw`, `http.internal`, `http.external` and `non_http`.

The SitemapScraper also returns:

* `locs`. Collection ot URLs.

## Error response

In case of error, Funkspector will return the `original_url` and the reason from the server:

```elixir
case Funkspector.page_scrape("http://example.com") do
  { :ok, data } ->
    IO.inspect(data)
  { :error, url, reason } ->
    IO.puts "Could not scrape #{url} because of #{reason}"
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add funkspector to your list of dependencies in `mix.exs`:

        def deps do
          [{:funkspector, "~> 0.1"}]
        end

  2. Ensure funkspector is started before your application:

        def application do
          [applications: [:funkspector]]
        end
