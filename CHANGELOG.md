# Changelog

All notable changes to Funkspector are documented in this file.

## [1.6.0](https://github.com/jaimeiniesta/funkspector/compare/940247c...842fe34) - 2025-11-20

- Add another TLS retry reason for SSL handshake failures.
- Upgrade HTTPoison to 2.3.0.
- Pin hackney to ~> 1.21.0 to work around [httpoison#501](https://github.com/edgurgel/httpoison/issues/501).
- Remove duplicated code.

## [1.5.0](https://github.com/jaimeiniesta/funkspector/compare/2f0b9ec...940247c) - 2025-11-07

- Extract and return canonical URL from `<link rel="canonical">` in page scrapes.

## [1.4.1](https://github.com/jaimeiniesta/funkspector/compare/c865fe5...2f0b9ec) - 2025-09-11

- Upgrade hackney.
- Remove support for Elixir 1.16.
- Fix tests and warnings.

## [1.4.0](https://github.com/jaimeiniesta/funkspector/compare/576f390...c865fe5) - 2024-12-24

- Add support for HTTP Basic Authentication via `:basic_auth` option ([#12](https://github.com/jaimeiniesta/funkspector/pull/12)).

## [1.3.0](https://github.com/jaimeiniesta/funkspector/compare/14483e0...576f390) - 2024-11-26

- Support Elixir 1.17 ([#11](https://github.com/jaimeiniesta/funkspector/pull/11)).

## [1.2.2](https://github.com/jaimeiniesta/funkspector/compare/daf6a55...14483e0) - 2024-09-04

- Return proper error for HTTP Status 300 (Multiple Choices) ([#10](https://github.com/jaimeiniesta/funkspector/pull/10)).

## [1.2.1](https://github.com/jaimeiniesta/funkspector/compare/ccf8442...daf6a55) - 2024-04-25

- Upgrade Floki dependency.

## [1.2.0](https://github.com/jaimeiniesta/funkspector/compare/5b0abba...ccf8442) - 2024-03-01

- Validate URLs before making requests, returning `{:error, url, :invalid_url}` for invalid ones ([#9](https://github.com/jaimeiniesta/funkspector/pull/9)).
- Add `Funkspector.resolve/2` as a top-level wrapper for `Resolver.resolve/2`.
- Upgrade HTTPoison to 2.2.1 and Floki to 0.35.4.

## [1.1.0](https://github.com/jaimeiniesta/funkspector/compare/c02012e...5b0abba) - 2023-10-23

- Upgrade Floki, ex_doc, and Credo.

## [1.0.0](https://github.com/jaimeiniesta/funkspector/compare/8478fd0...c02012e) - 2023-10-22

- Introduce `Funkspector.Document` struct to hold `url`, `contents`, and `data`.
- Refactor `PageScraper`, `SitemapScraper`, and `TextSitemapScraper` to use `Document` ([#8](https://github.com/jaimeiniesta/funkspector/pull/8)).
- Support loading pre-fetched contents via `:contents` option, skipping the HTTP request.
- Require Elixir 1.14 ([#7](https://github.com/jaimeiniesta/funkspector/pull/7)).
- Add new SSL retry reason.

## [0.9.1](https://github.com/jaimeiniesta/funkspector/compare/2c242be...8478fd0) - 2021-04-27

- Rename `:urls` to `:lines` in text sitemap data for consistency with other scrapers (`:links`, `:locs`).

## [0.9.0](https://github.com/jaimeiniesta/funkspector/compare/4891100...2c242be) - 2021-04-27

- Add `TextSitemapScraper` and `Funkspector.text_sitemap_scrape/2` for plain text sitemaps.

## [0.8.1](https://github.com/jaimeiniesta/funkspector/compare/b38cddf...4891100) - 2020-07-03

- Add another SSL retry case.
- Fix internal/external link classification to compare by host correctly.

## [0.8.0](https://github.com/jaimeiniesta/funkspector/compare/c2081b0...b38cddf) - 2020-04-28

- Include response headers in scraped data ([#5](https://github.com/jaimeiniesta/funkspector/pull/5)).
- Add default connect timeout.
- Trim raw links.
- Upgrade to Elixir 1.8, hackney, and HTTPoison.

## [0.7.1](https://github.com/jaimeiniesta/funkspector/compare/e5be0ca...c2081b0) - 2018-10-23

- Fix absolutification of relative links when `base_href` is itself a relative link.

## [0.7.0](https://github.com/jaimeiniesta/funkspector/compare/3fc533e...e5be0ca) - 2018-08-24

- Move default options (hackney, recv_timeout, user_agent) into `Funkspector` module.
- Pass options through to `Resolver`, `PageScraper`, and `SitemapScraper`.
- Accept configurable `user_agent` via options.
- Refactor Resolver to use a private `resolve_url/4` with a public `resolve/2` API.
- Switch from `Enum.partition` to `Enum.split_with`.
- Replace Friendly XML library with SweetXml.

## [0.5.0](https://github.com/jaimeiniesta/funkspector/compare/00a3d94...3fc533e) - 2018-05-13

- Upgrade dependencies.

## [0.4.2](https://github.com/jaimeiniesta/funkspector/compare/2ca1504...00a3d94) - 2017-11-30

- Use `<base href>` if present to absolutify relative links.

## [0.4.1](https://github.com/jaimeiniesta/funkspector/compare/c4f5bcd...2ca1504) - 2017-09-18

- Add another scenario for SSL version retry.

## [0.4.0](https://github.com/jaimeiniesta/funkspector/compare/77511e3...c4f5bcd) - 2017-06-05

- Upgrade HTTPoison to 0.11.
- Provide a browser-like User-Agent header.
- Retry with TLS version on SSL connection closed errors.

## [0.3.4](https://github.com/jaimeiniesta/funkspector/compare/62df20e...77511e3) - 2017-06-03

- Stop setting SSL option explicitly when using hackney insecure mode.
- Increase receive timeout to 25 seconds.

## [0.3.3](https://github.com/jaimeiniesta/funkspector/compare/9042413...62df20e) - 2017-05-11

- Handle `x-gzip` Content-Encoding in addition to `gzip`.

## [0.3.2](https://github.com/jaimeiniesta/funkspector/compare/d42f4af...9042413) - 2017-04-11

- Version bump (no functional changes).

## [0.3.1](https://github.com/jaimeiniesta/funkspector/compare/11eb8d7...d42f4af) - 2017-04-11

- Fix HTTPoison SSL connection closed error.

## [0.3.0](https://github.com/jaimeiniesta/funkspector/compare/8acf145...11eb8d7) - 2017-03-07

- Avoid crashes when parsing XML sitemaps that include comments.

## [0.2.0](https://github.com/jaimeiniesta/funkspector/compare/a574f0e...8acf145) - 2016-12-23

- Decompress gzip-encoded response bodies.
- Disable SSL certificate verification ([#4](https://github.com/jaimeiniesta/funkspector/pull/4)).
- Update dependencies.

## [0.1.5](https://github.com/jaimeiniesta/funkspector/compare/7a60b7d...a574f0e) - 2016-08-19

- Fix relative link absolutification to use the base URL instead of the root URL.

## [0.1.4](https://github.com/jaimeiniesta/funkspector/compare/41141d8...7a60b7d) - 2016-08-16

- Follow `Location` headers case-insensitively.

## [0.1.3](https://github.com/jaimeiniesta/funkspector/compare/c3a7053...41141d8) - 2016-08-04

- Revert Quinn dependency upgrade; pin to 0.0.4.

## [0.1.1](https://github.com/jaimeiniesta/funkspector/compare/940b482...c3a7053) - 2016-07-19

- Recover gracefully from malformed XML when scraping sitemaps.

## [0.1.0](https://github.com/jaimeiniesta/funkspector/compare/b995cc8...940b482) - 2016-07-19

- Rename `Scraper` to `PageScraper`.
- Add `SitemapScraper` for XML sitemaps using XPath.

## [0.0.3](https://github.com/jaimeiniesta/funkspector/compare/9b5dc02...b995cc8) - 2016-06-29

- Update dependencies.
- Add Travis CI configuration.

## [0.0.2](https://github.com/jaimeiniesta/funkspector/compare/7cf2fe4...9b5dc02) - 2016-06-22

- Absolutify relative links.
- Follow relative redirections.
- Set Elixir 1.3 as minimum version.
- Add documentation.

## [0.0.1](https://github.com/jaimeiniesta/funkspector/commit/7cf2fe4) - 2016-06-02

- Initial release.
- Page scraping: extract internal, external, and non-HTTP links.
- Handle redirections.
- Deduplicate links.
