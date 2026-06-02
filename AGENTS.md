# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

Funkspector is an Elixir library (Hex package) for web scraping. It extracts data from HTML pages, XML sitemaps, and text sitemaps. Version 2.0.0, requires Elixir ~> 1.17.

## Common Commands

```bash
# Install dependencies
mix deps.get

# Run unit tests (default, no network required)
mix test

# Run a single test file
mix test test/page_scraper_test.exs

# Run a specific test by line number
mix test test/page_scraper_test.exs:15

# Run integration tests (hit live URLs, require network)
mix test --include integration

# Run only integration tests
mix test --include integration --only integration

# Run the unit suite against the default Req adapter (mirrors `mix test`,
# but explicitly sets FUNKSPECTOR_ADAPTER=req for symmetry with test.httpoison)
mix test.req

# Run the unit suite against the opt-in HTTPoison adapter
mix test.httpoison

# Run the unit suite against both adapters back-to-back (CI runs this)
mix test.adapters

# Run everything (unit + integration, both adapters)
mix test.all

# Run a single integration file via the alias
mix test.all test/integration/tls_integration_test.exs

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

- `req` — default HTTP client (Finch/Mint). No hackney; the Req adapter avoids the [httpoison#501](https://github.com/edgurgel/httpoison/issues/501) constraint that caps hackney at ~> 1.21.
- `httpoison` / `hackney` — opt-in HTTP client. Declared as `optional: true`; required only when selecting `Funkspector.HTTP.Adapters.HTTPoison`.
- `floki` — HTML parsing
- `sweet_xml` — XML/XPath parsing
- `mock` (test only) — mocks the active HTTP adapter in tests

### HTTP Adapter

The HTTP transport is pluggable via `Funkspector.HTTP.Adapter`:

- `Funkspector.HTTP.Adapters.Req` (default)
- `Funkspector.HTTP.Adapters.HTTPoison` (opt-in)

Select with `config :funkspector, :http_adapter, …` or per-call via the `:adapter` option. Adapters return normalized `%Funkspector.Response{}` / `%Funkspector.Error{}` structs.

## Testing Conventions

Tests are split into two categories:

### Unit tests (default)
Run with `mix test`. No network access required. All HTTP calls are mocked using the `Mock` library. Mock responses are defined in `test/support/mocked_connections.exs`.

`test_helper.exs` reads the `FUNKSPECTOR_ADAPTER` env var and sets `Application.put_env(:funkspector, :http_adapter, …)` so the same suite runs cleanly under either adapter. `MockedConnections.current_adapter/0` returns the active module, and test files mock that module via an `@adapter current_adapter()` module attribute:

```elixir
@adapter current_adapter()

with_mock @adapter, get: fn _url, _opts -> successful_response() end do
  # test assertions
end
```

Use the dedicated aliases to run the suite against each adapter:

- `mix test` — Req adapter (default)
- `mix test.httpoison` — HTTPoison adapter
- `mix test.adapters` — both, sequentially (CI)

### Integration tests
Tagged with `@tag :integration` or `@moduletag :integration`. These hit live URLs and require network access. Excluded by default via `test_helper.exs`.

Run with `mix test --include integration`. `mix test.all` runs unit + integration against **both** adapters.

Integration tests live in:
- `test/docs_test.exs` — doctests for `Funkspector` and `Funkspector.Resolver` (live URL examples from `@doc`)
- `test/integration/*.exs` — TLS, redirect, sitemap, and resolver coverage against `httpbin.org`, `badssl.com`, etc.
- `test/resolver_test.exs` — hackney regression test (tagged individually with `@tag :integration`)
