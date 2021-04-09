defmodule Funkspector do
  @moduledoc """
  Funkspector is a web scraper that lets you extract data from web pages.
  """

  @doc """
  Convenience method, this is just a shortcut for `Funkspector.PageScraper.scrape/1`.

  ## Examples

      iex> { :ok, data } = Funkspector.page_scrape("http://example.com")
      iex> data.host
      "example.com"
  """
  def page_scrape(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    Funkspector.PageScraper.scrape(url, options)
  end

  @doc """
  Convenience method, this is just a shortcut for `Funkspector.SitemapScraper.scrape/1`.

  ## Examples

      iex> { :ok, data } = Funkspector.sitemap_scrape("https://rocketvalidator.com/sitemap.xml")
      iex> length data.locs
      502
      iex> [ first | _ ] = data.locs
      iex> first
      "https://rocketvalidator.com/"
  """
  def sitemap_scrape(url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    Funkspector.SitemapScraper.scrape(url, options)
  end

  def default_options do
    %{
      hackney: [:insecure],
      timeout: 28_000,
      recv_timeout: 25_000,
      user_agent: "Funkspector/0.6.0 (+https://hex.pm/packages/funkspector)"
    }
  end
end
