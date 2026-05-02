# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

Funkspector is an Elixir library (Hex package) for web scraping. It extracts data from HTML pages, XML sitemaps, and text sitemaps. Version 1.6.0, requires Elixir ~> 1.17.

## Common Commands

```bash
# Install dependencies
mix deps.get

# Run all tests
mix test

# Run a single test file
mix test test/page_scraper_test.exs

# Run a specific test by line number
mix test test/page_scraper_test.exs:15

# Lint (CI runs these)
mix compile --warnings-as-errors
mix format --check-formatted
mix deps.unlock --check-unused

# Auto-format code
mix format
```

## Architecture

All public functions live in `Funkspector` (`lib/funkspector.ex`) and follow the pattern:
- Success: `{:ok, %Funkspector.Document{url, contents, data}}` or `{:ok, final_url, response}` for resolve
- Error: `{:error, original_url, reason}`

### Module Pipeline

```
Funkspector (public API) → Resolver → Document → Scraper
```

- **Funkspector** — four public functions: `resolve/2`, `page_scrape/2`, `sitemap_scrape/2`, `text_sitemap_scrape/2`. All accept an optional `contents:` keyword to skip the HTTP request.
- **Resolver** — follows redirects (max 5 hops), handles SSL/TLS retries (fallback to tlsv1.2), decompresses gzip, supports basic auth.
- **Document** — struct holding `url`, `contents`, `data`. Handles HTTP requests via Resolver (`request/2`) or loads pre-fetched contents (`load/2`).
- **PageScraper** — uses Floki to extract `<a href>` links. Separates into `http.internal`, `http.external`, and `non_http`. Resolves relative URLs. Finds base href and canonical URL.
- **SitemapScraper** — uses SweetXml with XPath `//url/loc/text()` to extract URLs from XML sitemaps.
- **TextSitemapScraper** — splits text by newlines, filters empty lines.
- **Utils** — `absolutify/2` (relative→absolute URL via URI.merge), `valid_url?/1` (regex, supports internationalized domains).

### Key Dependencies

- `httpoison` / `hackney` — HTTP client. Hackney pinned to ~> 1.21.0 due to [httpoison#501](https://github.com/edgurgel/httpoison/issues/501).
- `floki` — HTML parsing
- `sweet_xml` — XML/XPath parsing
- `mock` (test only) — mocks HTTPoison in tests

## Testing Conventions

Tests use the `Mock` library to mock `HTTPoison.get/3` calls. Mock responses are defined in `test/support/mocked_connections.exs`. No real HTTP requests are made during tests.

Pattern used across test files:
```elixir
with_mock HTTPoison, [get: fn(_url, _headers, _options) -> MockedConnections.successful_response() end] do
  # test assertions
end
```
