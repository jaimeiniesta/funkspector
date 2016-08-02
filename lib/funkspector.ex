defmodule Funkspector do
  @moduledoc """
  Funkspector is a web scraper that lets you extract data from web pages.
  """

  @doc """
  Convenience method, this is just a shortcut for `Funkspector.PageScraper.scrape/1`.

  ## Examples

      iex> { :ok, data } = Funkspector.page_scrape("http://jaimeiniesta.com")
      iex> data.host
      "jaimeiniesta.com"
  """
  def page_scrape(url) do
    Funkspector.PageScraper.scrape(url)
  end

  @doc """
  Convenience method, this is just a shortcut for `Funkspector.SitemapScraper.scrape/1`.

  ## Examples

      iex> { :ok, data } = Funkspector.sitemap_scrape("http://validationhell.com/sitemap.xml")
      iex> length data.locs
      1006
      iex> [ first | _ ] = data.locs
      iex> first
      "http://validationhell.com/"
  """
  def sitemap_scrape(url) do
    Funkspector.SitemapScraper.scrape(url)
  end
end
