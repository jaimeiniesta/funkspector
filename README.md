# Funkspector

[![Travis](https://img.shields.io/travis/jaimeiniesta/funkspector.svg?style=flat-square)](https://travis-ci.org/jaimeiniesta/funkspector)
[![Hex.pm](https://img.shields.io/hexpm/v/funkspector.svg?style=flat-square)](https://hex.pm/packages/funkspector)
[![Deps Status](https://beta.hexfaktor.org/badge/all/github/jaimeiniesta/funkspector.svg)](https://beta.hexfaktor.org/github/jaimeiniesta/funkspector)

Web page inspector for Elixir.

Funkspector is a web scraper that lets you extract data from web pages.

## Usage

Simply pass Funkspector the URL to inspect and it will return its scraped data:

```elixir
iex> { :ok, data } = Funkspector.scrape("http://github.com")
```

## Scraped data

Currently Funkspector returns this scraped data from the given URL:

* `body`. Raw body.
* `original_url` and `final_url`. Funkspector follows redirections, here are the original URL given and the final one after following the redirections.
* `scheme`. Like, "http" or "https".
* `host`. Like, "github.com".
* `links`. Organized in `raw`, `http.internal`, `http.external` and `non_http`.
* `root_url`. Root url for the given URL. For `http://example.com/about` it will be `http://example.com`.

## Error response

In case of error, Funkspector will return the `original_url` and the response from the server:

```elixir
case Funkspector.scrape("http://example.com") do
  { :ok, data } ->
    IO.inspect(data)
  { :error, url, response } ->
    IO.puts "Could not scrape #{url} because of #{reason}"
end
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add funkspector to your list of dependencies in `mix.exs`:

        def deps do
          [{:funkspector, "~> 0.0.1"}]
        end

  2. Ensure funkspector is started before your application:

        def application do
          [applications: [:funkspector]]
        end
