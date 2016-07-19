defmodule SitemapScraperTest do
  use ExUnit.Case
  doctest Funkspector.SitemapScraper

  import Mock
  import Rocket.MockedConnections

  import Funkspector.SitemapScraper, only: [ scrape: 1 ]

  test "returns :ok for status in 2xx" do
    for status <- 200..201 do
      with_mock HTTPoison, [get: fn(_url) -> successful_response_for_sitemap(status) end] do
        { :ok, _results } = scrape("http://example.com/sitemap.xml")
      end
    end
  end

  test "returns :error for status other than 2xx" do
    for status <- [100, 301, 404, 500] do
      with_mock HTTPoison, [get: fn(_url) -> unsuccessful_response(status) end] do
        { :error, url, response } = scrape("http://example.com/sitemap.xml")

        assert url  == "http://example.com/sitemap.xml"
        assert response.status_code == status
      end
    end
  end

  test "returns the locs, absolutified" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response_for_sitemap end] do
      { :ok, results } = scrape("http://example.com/sitemap.xml")

      assert results.locs ==
        ["http://example.com/",
         "http://example.com/faqs",
         "http://example.com/about"]
    end
  end
end
