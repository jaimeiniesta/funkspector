defmodule TextSitemapScraperTest do
  use ExUnit.Case
  doctest Funkspector.TextSitemapScraper

  import Mock
  import Rocket.MockedConnections

  import Funkspector.TextSitemapScraper, only: [scrape: 1]

  test "returns :ok for status in 2xx" do
    for status <- 200..201 do
      with_mock HTTPoison,
        get: fn _url, _headers, _options -> successful_response_for_text_sitemap(status) end do
        {:ok, _results} = scrape("http://example.com/sitemap.txt")
      end
    end
  end

  test "returns :error for status other than 2xx" do
    for status <- [100, 301, 404, 500] do
      with_mock HTTPoison, get: fn _url, _headers, _options -> unsuccessful_response(status) end do
        {:error, url, response} = scrape("http://example.com/sitemap.txt")

        assert url == "http://example.com/sitemap.txt"
        assert response.status_code == status
      end
    end
  end

  test "returns the URLS from the lines, absolutified when needed" do
    with_mock HTTPoison,
      get: fn _url, _headers, _options -> successful_response_for_text_sitemap() end do
      {:ok, results} = scrape("http://example.com/sitemap.txt")

      assert results.urls ==
               [
                 "http://example.com/",
                 "http://example.com/about",
                 "http://example.com/faqs",
                 "http://docs.example.com"
               ]
    end
  end
end
