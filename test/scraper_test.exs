defmodule ScraperTest do
  use ExUnit.Case
  import Mock

  import Funkspector.Scraper, only: [ scrape: 1 ]

  test "returns :ok for status in 2xx" do
    for status <- 200..201 do
      with_mock HTTPoison, [get: fn(_url) -> successful_scraping(status) end] do
        { :ok, _results } = scrape("http://example.com")
      end
    end
  end

  # TODO: follow redirections
  test "returns :error for status other than 2xx" do
    for status <- [100, 301, 404, 500] do
      with_mock HTTPoison, [get: fn(_url) -> unsuccessful_scraping(status) end] do
        { :error, results } = scrape("http://example.com")

        assert results == "returned body"
      end
    end
  end

  test "returns the body" do
    with_mock HTTPoison, [get: fn(_url) -> successful_scraping end] do
      { :ok, results } = scrape("http://example.com")

      assert results.body == mocked_html
    end
  end

  defp unsuccessful_scraping(status) do
    { :ok, %{ status_code: status, body: "returned body" } }
  end

  defp successful_scraping(status \\ 200) do
    { :ok, %{ status_code: status, body: mocked_html } }
  end

  defp mocked_html do
    """
    <html>
      <head>
        <title>An example page</title>
      </head>
      <body>
        <!-- Internal relative links -->
        <a href="/">Root</a>
        <a href="/faqs">FAQs</a>
        <a href="contact">Contact</a>

        <!-- Internal absolute links -->
        <a href="http://example.com/team.html">Team</a>

        <!-- External links -->
        <a href="https://twitter.com">Twitter</a>
        <a href="https://github.com">Github</a>

        <!-- Non-HTTP links -->
        <a href="mailto:hello@example.com">email</a>
        <a href="javascript:alert('hi');">hello</a>
        <a href="ftp://ftp.example.com">FTP</a>
      </body>
    </html>
    """
  end
end
