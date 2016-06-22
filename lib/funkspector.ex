defmodule Funkspector do
  @moduledoc """
  Funkspector is a web scraper that lets you extract data from web pages.
  """

  @doc """
  Convenience method, this is just a shortcut for `Funkspector.Scraper.scrape/1`.
  """
  def scrape(url) do
    Funkspector.Scraper.scrape(url)
  end
end
