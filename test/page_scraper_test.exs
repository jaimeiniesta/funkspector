defmodule PageScraperTest do
  use ExUnit.Case

  alias Funkspector.Document

  import FunkspectorTest.MockedConnections, only: [mocked_html: 0, mocked_html_with_base_href: 1]

  alias Funkspector.PageScraper

  setup do
    url = "https://example.com/page"
    html = mocked_html()

    {:ok, url: url, html: html}
  end

  test "scrapes data", %{url: url, html: html} do
    html_doc = %Document{url: url, body: html, data: nil}

    {:ok, document} = PageScraper.parse(html_doc)

    assert document == %Document{
             url: url,
             body: html,
             data: %{
               scheme: "https",
               host: "example.com",
               urls: %{
                 base_url: "https://example.com/page",
                 root_url: "https://example.com/"
               },
               links: %{
                 http: %{
                   internal: [
                     "http://example.com/",
                     "http://example.com/faqs",
                     "http://example.com/contact",
                     "https://example.com/secure.html",
                     "https://example.com/relative-1",
                     "https://example.com/relative-2",
                     "https://example.com/relative-3?q=some#results"
                   ],
                   external: [
                     "https://twitter.com",
                     "https://github.com",
                     "http://example.com.br",
                     "http://example.com.mx/faqs"
                   ]
                 },
                 non_http: [
                   "mailto:hello@example.com",
                   "javascript:alert('hi');",
                   "ftp://ftp.example.com"
                 ],
                 raw: [
                   "http://example.com/",
                   "http://example.com/faqs",
                   "http://example.com/contact",
                   "https://example.com/secure.html",
                   "/relative-1",
                   "relative-2",
                   "relative-3?q=some#results",
                   "https://twitter.com",
                   "https://github.com",
                   "http://example.com.br",
                   "http://example.com.mx/faqs",
                   "mailto:hello@example.com",
                   "javascript:alert('hi');",
                   "ftp://ftp.example.com"
                 ]
               }
             }
           }
  end

  test "respects existing data", %{url: url, html: html} do
    headers = %{
      "content-length" => "293427",
      "content-type" => "text/html;charset=utf-8"
    }

    data = %{
      headers: headers,
      urls: %{original_url: "http://example.com"}
    }

    html_doc = %Document{url: url, body: html, data: data}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.headers == headers

    assert data.urls == %{
             original_url: "http://example.com",
             base_url: "https://example.com/page",
             root_url: "https://example.com/"
           }
  end

  test "returns the scheme and host", %{html: html} do
    for {url, scheme, host} <- [
          {"http://example.com", "http", "example.com"},
          {"http://www.example.com/", "http", "www.example.com"},
          {"https://example.net/faqs?id=2", "https", "example.net"}
        ] do
      html_doc = %Document{url: url, body: html, data: nil}

      {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

      assert data.scheme == scheme
      assert data.host == host
    end
  end

  test "returns the root_url", %{html: html} do
    for {url, root_url} <- [
          {"http://example.com", "http://example.com/"},
          {"http://www.example.com/#pricing", "http://www.example.com/"},
          {"https://example.net/faqs?id=2", "https://example.net/"}
        ] do
      html_doc = %Document{url: url, body: html, data: nil}

      {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

      assert data.urls.root_url == root_url
    end
  end

  test "returns the raw links", %{url: url, html: html} do
    html_doc = %Document{url: url, body: html, data: nil}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.links.raw ==
             [
               "http://example.com/",
               "http://example.com/faqs",
               "http://example.com/contact",
               "https://example.com/secure.html",
               "/relative-1",
               "relative-2",
               "relative-3?q=some#results",
               "https://twitter.com",
               "https://github.com",
               "http://example.com.br",
               "http://example.com.mx/faqs",
               "mailto:hello@example.com",
               "javascript:alert('hi');",
               "ftp://ftp.example.com"
             ]
  end

  test "returns the internal links, including absolute and relative ones", %{url: url, html: html} do
    html_doc = %Document{url: url, body: html, data: nil}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.urls.base_url == url

    assert data.links.http.internal ==
             [
               "http://example.com/",
               "http://example.com/faqs",
               "http://example.com/contact",
               "https://example.com/secure.html",
               "https://example.com/relative-1",
               "https://example.com/relative-2",
               "https://example.com/relative-3?q=some#results"
             ]
  end

  test "relative links are calculated from the url when there is no base href specified", %{
    html: html
  } do
    url = "https://example.com/a/nested/directory/"
    html_doc = %Document{url: url, body: html, data: nil}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.urls.base_url == url

    assert data.links.http.internal ==
             [
               "http://example.com/",
               "http://example.com/faqs",
               "http://example.com/contact",
               "https://example.com/secure.html",
               "https://example.com/relative-1",
               "https://example.com/a/nested/directory/relative-2",
               "https://example.com/a/nested/directory/relative-3?q=some#results"
             ]
  end

  test "relative links are calculated from the base url when it is specified in the document" do
    base_url = "http://example.com/base/"
    html = mocked_html_with_base_href(base_url)

    html_doc = %Document{url: "https://example.com/a/nested/directory/", body: html, data: nil}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.urls.base_url == "http://example.com/base/"

    assert data.links.http.internal ==
             [
               "http://example.com/",
               "http://example.com/faqs",
               "http://example.com/contact",
               "https://example.com/secure.html",
               "http://example.com/relative-1",
               "http://example.com/base/relative-2",
               "http://example.com/base/relative-3?q=some#results"
             ]
  end

  test "returns the external links", %{url: url, html: html} do
    html_doc = %Document{url: url, body: html, data: nil}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.links.http.external ==
             [
               "https://twitter.com",
               "https://github.com",
               "http://example.com.br",
               "http://example.com.mx/faqs"
             ]
  end

  test "returns the non-http links", %{url: url, html: html} do
    html_doc = %Document{url: url, body: html, data: nil}

    {:ok, %Document{data: data}} = PageScraper.parse(html_doc)

    assert data.links.non_http == [
             "mailto:hello@example.com",
             "javascript:alert('hi');",
             "ftp://ftp.example.com"
           ]
  end
end
