# Roadmap: Porting MetaInspector features to Funkspector

Feature parity target: [MetaInspector](https://github.com/jaimeiniesta/metainspector) v5.17.1 (Ruby gem).

## What Funkspector already has

- [x] URL resolution with redirect following (up to 5 hops)
- [x] SSL/TLS version fallback (retry with TLSv1.2)
- [x] Gzip decompression
- [x] Basic authentication
- [x] Custom User-Agent
- [x] Link extraction (raw, internal, external, non-HTTP)
- [x] Base href detection
- [x] Canonical URL detection
- [x] URL absolutification (relative to absolute)
- [x] URL validation (with internationalized domain support)
- [x] Pre-loaded content support (skip HTTP request via `contents:` option)
- [x] XML sitemap scraping (not in MetaInspector)
- [x] Text sitemap scraping (not in MetaInspector)

## Phase 1: Meta tags and text extraction

Core content extraction that MetaInspector is best known for.

### Meta tags

Extract all `<meta>` tags from `<head>`, grouped by attribute type:

- `meta_tags` - nested map with keys `"name"`, `"http-equiv"`, `"property"`, `"charset"`. Values are lists (to support repeated tags like multiple `og:image`).
- `meta_tag` - same structure but singular values (first occurrence only).
- `meta` - flat merged map for simple access (`meta["og:title"]`, `meta["description"]`).

All keys should be downcased.

### Page title

- `title` - text from `<head><title>` tag.
- `best_title` - smart selection in priority order:
  1. `<meta name="title">` value
  2. `og:title` meta property
  3. `<head><title>` text
  4. `<body><title>` text (rare but exists)
  5. First `<h1>` text

### Description

- `description` - `<meta name="description">` content.
- `best_description` - smart selection:
  1. Meta description
  2. `og:description` meta property
  3. `twitter:description` meta property
  4. First `<p>` tag with 120+ characters

### Author

- `author` - `<meta name="author">` content.
- `best_author` - smart selection:
  1. Meta author
  2. `<a rel="author">` link text
  3. `<address>` tag text
  4. `twitter:creator` meta property

### Headings

- `h1` through `h6` - lists of text content from each heading level.

### Charset

- `charset` - from `<meta charset="...">` or `<meta http-equiv="Content-Type">`.

## Phase 2: Images and head links

### Image extraction

- `images` - list of all `<img src>` URLs, absolutified.
- `images.best` - best image: `og:image` > `twitter:image` > largest image.
- `images.largest` - largest image by area, filtering extreme aspect ratios (ratio between 0.1 and 10).
- `images.owner_suggested` - `og:image` or `twitter:image`, or nil.
- `images.favicon` - from `<link rel="icon">` or `<link rel="shortcut icon">`.
- `images.with_size` - list of `{url, width, height}` tuples sorted by descending area. Uses HTML `width`/`height` attributes.

### Head links

- `head_links` - list of all `<link>` elements from `<head>`, each as a map of attributes with absolutified `href`.
- `stylesheets` - filtered head links where `rel="stylesheet"`.
- `canonicals` - filtered head links where `rel="canonical"` (as list, since there could be multiple).
- `feeds` - `<link rel="alternate">` with type `application/rss+xml`, `application/atom+xml`, or `application/json`. Returns list of maps with `title`, `href`, `type`.

## Phase 3: URL features and response access

### URL normalization

- Normalize URLs by default (add scheme, trailing slash, percent-encode international characters).
- `normalize_url: false` option to disable.

### UTM tracking detection

- `tracked?` - boolean, true if URL contains `utm_source`, `utm_medium`, `utm_term`, `utm_content`, or `utm_campaign` parameters.
- `untracked_url` - URL with tracking parameters stripped.

### Response access

- `response.status` - HTTP status code.
- `response.headers` - response headers as a map.
- `content_type` - MIME type from Content-Type header (without charset).

### URL properties

Funkspector already has `urls.parsed`, `urls.root`, etc. Expose these more explicitly:

- `scheme` - URL scheme (`http`, `https`).
- `host` - hostname.
- `root_url` - `scheme://host/`.

## Phase 4: Configuration and error handling

### Options

- `connection_timeout` - connection timeout (already have `timeout`).
- `read_timeout` - receive timeout (already have `recv_timeout`).
- `retries` - number of retry attempts on failure (MetaInspector defaults to 3).
- `headers` - custom HTTP request headers (generalize beyond User-Agent).
- `allow_redirections` - boolean to enable/disable redirect following (currently always enabled).
- `max_redirects` - maximum number of redirects to follow (currently hardcoded to 5, MetaInspector uses 10).
- `allow_non_html_content` - boolean, return error for non-HTML content types (default false).
- `encoding` - force document encoding for pages with invalid UTF-8.

### Error types

Define specific error atoms or structs:

- `:timeout` - request timed out.
- `:request_error` - connection failed, invalid URI, SSL error.
- `:non_html_content` - response is not HTML (when `allow_non_html_content: false`).

### Cookie handling

- Persist cookies across redirect hops (MetaInspector uses a cookie jar during redirects).

## Phase 5: Serialization and advanced features

### Serialization

- `to_map` - returns a flat map with all extracted data (equivalent to MetaInspector's `to_hash`). Useful for JSON serialization or storage.

### HTTP caching

- Optional response caching to avoid re-fetching the same URL. Consider integration with ETS or a configurable cache backend.

### Image size detection

- Option to fetch image headers to determine dimensions (equivalent to FastImage). Lower priority since it requires additional HTTP requests per image.

## Out of scope

These MetaInspector features don't apply or have Elixir equivalents:

- **Nokogiri document access** (`parsed`) - Funkspector uses Floki; users can call `Floki.parse_document!/1` on `document.contents` directly.
- **Faraday middleware** - Funkspector uses HTTPoison/Hackney; middleware patterns differ in Elixir.
- **Lazy evaluation** - MetaInspector defers HTTP requests until data is accessed. Funkspector's functional API (`page_scrape/2` returns everything at once) is more idiomatic in Elixir.
