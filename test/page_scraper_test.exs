defmodule PageScraperTest do
  use ExUnit.Case
  doctest Funkspector.PageScraper

  import Mock
  import Rocket.MockedConnections

  import Funkspector.PageScraper, only: [ scrape: 1 ]

  test "returns :ok for status in 2xx" do
    for status <- 200..201 do
      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response(status) end] do
        { :ok, _results } = scrape("http://example.com")
      end
    end
  end

  test "returns :error for status other than 2xx" do
    for status <- [100, 301, 404, 500] do
      with_mock HTTPoison, [get: fn(_url, _headers, _options) -> unsuccessful_response(status) end] do
        { :error, url, response } = scrape("http://example.com")

        assert url  == "http://example.com"
        assert response.status_code == status
      end
    end
  end

  test "returns the scheme and host" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      for url <- ["http://example.com", "http://example.com/", "http://example.com/faqs?id=2"] do
        { :ok, results } = scrape(url)

        assert results.scheme == "http"
        assert results.host   == "example.com"
      end
    end
  end

  test "returns the root url" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      for url <- ["http://example.com", "http://example.com/", "http://example.com/faqs?id=2"] do
        { :ok, results } = scrape(url)

        assert results.root_url == "http://example.com/"
      end
    end
  end

  test "returns the body" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      { :ok, results } = scrape("http://example.com")

      assert results.body == mocked_html()
    end
  end

  test "returns the raw links" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.raw ==
        ["http://example.com/",
         "http://example.com/faqs",
         "http://example.com/contact",
         "https://example.com/secure.html",
         "/relative-1",
         "relative-2",
         "relative-3?q=some#results",
         "https://twitter.com",
         "https://github.com",
         "mailto:hello@example.com",
         "javascript:alert('hi');",
         "ftp://ftp.example.com"]
    end
  end

  test "returns the internal links, including absolute and relative ones" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.http.internal ==
        ["http://example.com/",
         "http://example.com/faqs",
         "http://example.com/contact",
         "https://example.com/secure.html",
         "http://example.com/relative-1",
         "http://example.com/relative-2",
         "http://example.com/relative-3?q=some#results"]
    end
  end

  test "relative links are calculated from the root url when there is no base href specified" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      { :ok, results } = scrape("http://example.com/a/nested/directory/")

      assert results.links.http.internal ==
        ["http://example.com/",
         "http://example.com/faqs",
         "http://example.com/contact",
         "https://example.com/secure.html",
         "http://example.com/relative-1",
         "http://example.com/a/nested/directory/relative-2",
         "http://example.com/a/nested/directory/relative-3?q=some#results"]
    end
  end

  test "relative links are calculated from the base url when it is specified in the document" do
    base_url = "http://example.com/base/"

    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response_with_base_href(base_url) end] do
      { :ok, results } = scrape("http://example.com/a/nested/directory/")

      assert results.links.http.internal ==
        ["http://example.com/",
         "http://example.com/faqs",
         "http://example.com/contact",
         "https://example.com/secure.html",
         "http://example.com/relative-1",
         "http://example.com/base/relative-2",
         "http://example.com/base/relative-3?q=some#results"]
    end
  end

  test "returns the external links" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.http.external ==
        ["https://twitter.com", "https://github.com"]
    end
  end

  test "returns the non-http links" do
    with_mock HTTPoison, [get: fn(_url, _headers, _options) -> successful_response() end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.non_http ==
        ["mailto:hello@example.com", "javascript:alert('hi');",
        "ftp://ftp.example.com"]
    end
  end

  test "follows redirections" do
    with_mock HTTPoison, [get: fn(url, _headers, _options) -> redirect_from(url) end] do
      { :ok, results } = scrape("http://example.com/redirect/1")

      assert results.original_url == "http://example.com/redirect/1"
      assert results.final_url    == "http://example.com/redirect/3"
    end
  end
end
