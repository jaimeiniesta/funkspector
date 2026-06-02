# Funkspector

[![Hex.pm](https://img.shields.io/hexpm/v/funkspector.svg?style=flat-square)](https://hex.pm/packages/funkspector)

Web page inspector for Elixir.

Funkspector is a web scraper that lets you extract data from web pages and XML or TXT sitemaps.

## Installation

Add funkspector to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:funkspector, "~> 2.0"}]
end
```

Funkspector 2.0 uses [Req](https://hex.pm/packages/req) (Finch/Mint) as its
default HTTP transport. [HTTPoison](https://hex.pm/packages/httpoison) remains
available as an opt-in adapter — see [HTTP Adapter](#http-adapter) below.

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

> Note: `recv_timeout` is a per-chunk receive timeout, not a bound on total
> request time.

#### Disabling TLS verification

TLS certificates are verified by default. To scrape a host with a broken,
self-signed, or expired certificate, opt out explicitly (this disables MITM
protection for that request, so use it deliberately):

```elixir
Funkspector.page_scrape("https://self-signed.example.com", %{insecure: true})
```

#### Limiting the response body size

`max_body_size` (default 100 MB) bounds both the raw response body and gzip
decompression, protecting against memory exhaustion and decompression bombs
when scraping untrusted URLs. Oversized responses return
`%Funkspector.Error{reason: :body_too_large}`. Set `:infinity` to disable:

```elixir
Funkspector.page_scrape("https://example.com", %{max_body_size: 5_000_000})
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

The `reason` is one of:

- `:invalid_url` — the URL failed Funkspector's syntax/TLD validation.
- A `%Funkspector.Error{reason: atom, adapter: module}` — a transport
  failure (e.g., `:nxdomain`, `:timeout`, `:closed`, `{:tls_alert, _}`).
  The `:reason` atom comes from `gen_tcp`/`inet`, so the contract is the
  same across adapters.
- A `%Funkspector.Response{status_code: integer}` — a non-2xx HTTP
  response (e.g., 404, 500, 300).

## HTTP Adapter

Funkspector 2.0 ships with two HTTP adapters:

- `Funkspector.HTTP.Adapters.Req` (**default**) — backed by
  [Req](https://hex.pm/packages/req)/Finch/Mint. No `hackney` dependency, so
  it is unaffected by the hackney 1.21 issues
  ([CVE-2026-47075](https://nvd.nist.gov/vuln/detail/CVE-2026-47075),
  [CVE-2026-47076](https://nvd.nist.gov/vuln/detail/CVE-2026-47076)) whose fix
  in hackney 4.0.1 is blocked for HTTPoison by
  [httpoison#501](https://github.com/edgurgel/httpoison/issues/501).
- `Funkspector.HTTP.Adapters.HTTPoison` — backed by
  [HTTPoison](https://hex.pm/packages/httpoison)/hackney. Opt-in for users who
  want to preserve the pre-2.0 transport; note it carries the hackney 1.21
  CVEs above.

### Switching the default adapter

Set the adapter app-wide in your `config/config.exs`:

```elixir
config :funkspector, :http_adapter, Funkspector.HTTP.Adapters.HTTPoison
```

You'll also need to declare `httpoison` (and `hackney`) in your own
`mix.exs` deps since Funkspector marks them `optional: true`:

```elixir
{:httpoison, "~> 2.3"}
```

### Per-call override

Pass `:adapter` in the options map to override on a single call:

```elixir
Funkspector.resolve("https://example.com", %{
  adapter: Funkspector.HTTP.Adapters.HTTPoison
})
```

### Migrating from 1.x

The error and response structs are normalized across adapters:

```elixir
# Funkspector 1.x
{:error, url, %HTTPoison.Error{reason: :nxdomain, id: nil}}

# Funkspector 2.0
{:error, url, %Funkspector.Error{reason: :nxdomain, adapter: _}}
```

The `:reason` atom is unchanged, so most pattern matches require only a
struct rename.

## Security considerations

Funkspector fetches whatever URL you give it and follows redirects, so when
you point it at untrusted or user-supplied URLs, keep in mind:

- **No SSRF filtering.** `valid_url?/1` accepts `localhost`, IP-literal hosts
  (including private ranges like `10.0.0.0/8`, link-local `169.254.169.254`,
  and IPv6 loopback), and these are reachable both directly and via a redirect
  from a public URL. Funkspector does not block them — enforce your own
  allow/deny policy or network-level egress controls before fetching
  attacker-influenced URLs. Note that input validation alone is insufficient,
  because a public URL can redirect to an internal one.
- **TLS is verified by default.** Disable it only deliberately, per call, with
  `%{insecure: true}`.
- **Bound the response size** with `max_body_size` (on by default at 100 MB)
  when scraping untrusted hosts.
- **`links.http.internal` is not a security boundary** — it is a host-string
  match against the final fetched host and honors the page's `<base href>`.
  Re-validate any extracted URL before fetching it.
