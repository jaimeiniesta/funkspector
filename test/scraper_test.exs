defmodule ScraperTest do
  use ExUnit.Case
  import Mock
  import Rocket.MockedConnections

  import Funkspector.Scraper, only: [ scrape: 1 ]

  test "returns :ok for status in 2xx" do
    for status <- 200..201 do
      with_mock HTTPoison, [get: fn(_url) -> successful_response(status) end] do
        { :ok, _results } = scrape("http://example.com")
      end
    end
  end

  test "returns :error for status other than 2xx" do
    for status <- [100, 301, 404, 500] do
      with_mock HTTPoison, [get: fn(_url) -> unsuccessful_response(status) end] do
        { :error, url, response } = scrape("http://example.com")

        assert url  == "http://example.com"
        assert response.status_code == status
      end
    end
  end

  test "returns the scheme and host" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      for url <- ["http://example.com", "http://example.com/", "http://example.com/faqs?id=2"] do
        { :ok, results } = scrape(url)

        assert results.scheme == "http"
        assert results.host   == "example.com"
      end
    end
  end

  test "returns the root url" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      for url <- ["http://example.com", "http://example.com/", "http://example.com/faqs?id=2"] do
        { :ok, results } = scrape(url)

        assert results.root_url == "http://example.com/"
      end
    end
  end

  test "returns the body" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      { :ok, results } = scrape("http://example.com")

      assert results.body == mocked_html
    end
  end

  test "returns the raw links" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.raw ==
        ["http://example.com/", "http://example.com/faqs", "http://example.com/contact",
         "https://example.com/secure.html", "https://twitter.com",
         "https://github.com", "mailto:hello@example.com", "javascript:alert('hi');",
         "ftp://ftp.example.com"]
    end
  end

  test "returns the internal links" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.http.internal ==
        ["http://example.com/", "http://example.com/faqs", "http://example.com/contact",
         "https://example.com/secure.html"]
    end
  end

  test "returns the external links" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.http.external ==
        ["https://twitter.com", "https://github.com"]
    end
  end

  test "returns the non-http links" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      { :ok, results } = scrape("http://example.com")

      assert results.links.non_http ==
        ["mailto:hello@example.com", "javascript:alert('hi');",
        "ftp://ftp.example.com"]
    end
  end

  test "follows redirections" do
    with_mock HTTPoison, [get: fn(url) -> redirect_from(url) end] do
      { :ok, results } = scrape("http://example.com/redirect/1")

      assert results.original_url == "http://example.com/redirect/1"
      assert results.final_url    == "http://example.com/redirect/3"
    end
  end
end
