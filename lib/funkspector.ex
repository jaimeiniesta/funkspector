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
      iex> data.locs
      ["http://validationhell.com/", "http://validationhell.com/pages/faqs", "http://validationhell.com/pages/agent",
       "http://validationhell.com/pages/how", "http://validationhell.com/pages/why",
       "http://validationhell.com/pages/circle/1", "http://validationhell.com/pages/circle/2",
       "http://validationhell.com/pages/circle/3", "http://validationhell.com/pages/circle/4",
       "http://validationhell.com/pages/circle/5", "http://validationhell.com/pages/circle/6",
       "http://validationhell.com/pages/circle/7", "http://validationhell.com/pages/circle/8",
       "http://validationhell.com/pages/circle/9", "http://validationhell.com/pages/abyss/1"]
  """
  def sitemap_scrape(url) do
    Funkspector.SitemapScraper.scrape(url)
  end
end
