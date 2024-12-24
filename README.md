# Funkspector

[![Hex.pm](https://img.shields.io/hexpm/v/funkspector.svg?style=flat-square)](https://hex.pm/packages/funkspector)

Web page inspector for Elixir.

Funkspector is a web scraper that lets you extract data from web pages and XML or TXT sitemaps.

## Usage

### Resolving URLs

Simply pass Funkspector the URL to resolve and it will return its final URL after following redirections:

```elixir
iex> { :ok, final_url, _ } = Funkspector.resolve("http://example.com")
```

### Page Scraping

Simply pass Funkspector the URL of a web page to inspect and it will return its scraped data:

```elixir
iex> { :ok, document } = Funkspector.page_scrape("https://rocketvalidator.com")
```

### Sitemap Scraping

Funkspector can extract the locations from XML sitemaps, like this:

```elixir
iex> { :ok, document } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.xml")
```

It also supports TXT sitemaps:

```elixir
iex> { :ok, document } = Funkspector.text_sitemap_scrape("https://rocketvalidator.com/sitemap.txt")
```
### Custom User Agent

You can specify a custom User Agent string using the `user_agent` option.

Example:
```elixir
  Funkspector.page_scrape("http://example.com", %{user_agent: "My Bot"})
```

### Basic Auth

You can specify a basic auth username and password using the `basic_auth` option, which will be passed as an `Authorization` request header.

Example:
```elixir
  Funkspector.page_scrape("http://example.com", %{basic_auth: {"user", "secret"}})
```

### Setting a custom timeout

Use `recv_timeout` to set a custom timeout for the request, in milliseconds.

Example:
```elixir
  Funkspector.page_scrape("http://example.com", %{recv_timeout: 5_000})
```

### Loading a document contents instead of requesting

You can skip the HTTP request of the document if you already have the contents of the document. This is useful in cases where you already have the contents from a previous request or cache. For example:

```elixir
Funkspector.page_scrape("https://example.com", contents: "<html>...</html>")

```

### Scraped data

For a successful response you'll get a `Funkspector.Document` with the scraped data, which will depend on the kind of scraper used. All data will be found inside the `:data` attribute. 

## Error response

In case of error, Funkspector will return the `original_url` and the reason from the server:

```elixir
case Funkspector.page_scrape("http://example.com") do
  { :ok, document } ->
    IO.inspect(data)
  { :error, url, reason } ->
    IO.puts "Could not scrape #{url} because of #{reason}"
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add funkspector to your list of dependencies in `mix.exs`:

        def deps do
          [{:funkspector, "~> 0.10"}]
        end

  2. Ensure funkspector is started before your application:

        def application do
          [applications: [:funkspector]]
        end
