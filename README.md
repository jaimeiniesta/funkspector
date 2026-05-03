# Funkspector

[![Hex.pm](https://img.shields.io/hexpm/v/funkspector.svg?style=flat-square)](https://hex.pm/packages/funkspector)

Web page inspector for Elixir.

Funkspector is a web scraper that lets you extract data from web pages and XML or TXT sitemaps.

## Installation

Add funkspector to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:funkspector, "~> 1.6"}]
end
```

## Usage

### Resolving URLs

Pass Funkspector a URL to resolve and it will return the final URL after following redirections:

```elixir
{:ok, final_url, response} = Funkspector.resolve("http://example.com")
```

### Page Scraping

Pass Funkspector the URL of a web page and it will return a `Funkspector.Document` with the scraped data:

```elixir
{:ok, document} = Funkspector.page_scrape("https://example.com")
```

The returned `document.data` contains:

```elixir
%{
  urls: %{
    original: "https://example.com",
    base: "https://example.com",
    canonical: nil,
    parsed: %{scheme: "https", host: "example.com", ...},
    root: "https://example.com/"
  },
  links: %{
    raw: ["/about", "https://other.com", ...],
    http: %{
      internal: ["https://example.com/about", ...],
      external: ["https://other.com", ...]
    },
    non_http: ["mailto:hi@example.com", ...]
  },
  headers: %{"content-type" => "text/html;charset=utf-8", ...}
}
```

### Sitemap Scraping

Funkspector can extract the locations from XML sitemaps:

```elixir
{:ok, document} = Funkspector.sitemap_scrape("https://example.com/sitemap.xml")
document.data.locs
# => ["https://example.com/", "https://example.com/about", ...]
```

It also supports plain text sitemaps:

```elixir
{:ok, document} = Funkspector.text_sitemap_scrape("https://example.com/sitemap.txt")
document.data.lines
# => ["https://example.com/", "https://example.com/about", ...]
```

### Options

#### Custom User Agent

```elixir
Funkspector.page_scrape("https://example.com", %{user_agent: "My Bot"})
```

#### Basic Auth

```elixir
Funkspector.page_scrape("https://example.com", %{basic_auth: {"user", "secret"}})
```

#### Custom timeout

Use `recv_timeout` to set a custom timeout in milliseconds:

```elixir
Funkspector.page_scrape("https://example.com", %{recv_timeout: 5_000})
```

#### Loading pre-fetched contents

You can skip the HTTP request if you already have the document contents:

```elixir
Funkspector.page_scrape("https://example.com", %{contents: "<html>...</html>"})
Funkspector.sitemap_scrape("https://example.com/sitemap.xml", %{contents: "<xml>...</xml>"})
Funkspector.text_sitemap_scrape("https://example.com/sitemap.txt", %{contents: "..."})
```

## Error handling

In case of error, Funkspector returns the original URL and the reason:

```elixir
case Funkspector.page_scrape("https://example.com") do
  {:ok, document} ->
    IO.inspect(document.data)
  {:error, url, reason} ->
    IO.puts("Could not scrape #{url} because of #{inspect(reason)}")
end
```
