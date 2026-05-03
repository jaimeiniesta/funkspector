defmodule PageScraperTest do
  use ExUnit.Case

  alias Funkspector.{Document, PageScraper}

  import FunkspectorTest.MockedConnections,
    only: [mocked_html: 0, mocked_html_with_base_href: 1, mocked_html_with_canonical_url: 1]

  setup do
    url = "https://example.com/page"
    html = mocked_html()

    {:ok, document} = Document.load(url, html)

    {:ok, url: url, html: html, document: document}
  end

  test "scrapes data", %{url: url, html: html, document: document} do
    {:ok, document} = PageScraper.scrape(document)

    assert document == %Document{
             url: url,
             contents: html,
             data: %{
               urls: %{
                 parsed: %{
                   scheme: "https",
                   authority: "example.com",
                   userinfo: nil,
                   host: "example.com",
                   port: 443,
                   path: "/page",
                   query: nil,
                   fragment: nil
                 },
                 base: "https://example.com/page",
                 root: "https://example.com/",
                 canonical: nil
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

  test "returns the raw links", %{document: document} do
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

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

  test "returns the internal links, including absolute and relative ones", %{
    url: url,
    document: document
  } do
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls.base == url

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
    {:ok, document} = Document.load(url, html)

    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls.base == url

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

  test "includes canonical_url if present" do
    url = "https://example.com/blog?page=2"
    canonical_url = "https://example.com/blog"

    html = mocked_html_with_canonical_url(canonical_url)

    {:ok, document} = Document.load(url, html)

    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls == %{
             root: "https://example.com/",
             base: "https://example.com/blog?page=2",
             canonical: canonical_url,
             parsed: %{
               port: 443,
               scheme: "https",
               path: "/blog",
               host: "example.com",
               userinfo: nil,
               fragment: nil,
               query: "page=2",
               authority: "example.com"
             }
           }
  end

  test "absolutifies canonical url if it's relative" do
    url = "https://example.com/blog?page=2"
    relative_canonical_url = "/blog"
    expected_canonical_url = "https://example.com/blog"

    html = mocked_html_with_canonical_url(relative_canonical_url)

    {:ok, document} = Document.load(url, html)

    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls == %{
             root: "https://example.com/",
             base: "https://example.com/blog?page=2",
             canonical: expected_canonical_url,
             parsed: %{
               port: 443,
               scheme: "https",
               path: "/blog",
               host: "example.com",
               userinfo: nil,
               fragment: nil,
               query: "page=2",
               authority: "example.com"
             }
           }
  end

  test "returns nil canonical_url if not present" do
    url = "https://example.com/blog?page=2"

    html = mocked_html()

    {:ok, document} = Document.load(url, html)

    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls == %{
             root: "https://example.com/",
             base: "https://example.com/blog?page=2",
             canonical: nil,
             parsed: %{
               port: 443,
               scheme: "https",
               path: "/blog",
               host: "example.com",
               userinfo: nil,
               fragment: nil,
               query: "page=2",
               authority: "example.com"
             }
           }
  end

  test "relative links are calculated from the base url when it is specified in the document" do
    url = "https://example.com/a/nested/directory/"
    base_url = "http://example.com/base/"
    html = mocked_html_with_base_href(base_url)

    {:ok, document} = Document.load(url, html)

    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls.base == "http://example.com/base/"

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

  test "returns the external links", %{document: document} do
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.http.external ==
             [
               "https://twitter.com",
               "https://github.com",
               "http://example.com.br",
               "http://example.com.mx/faqs"
             ]
  end

  test "returns the non-http links", %{document: document} do
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.non_http == [
             "mailto:hello@example.com",
             "javascript:alert('hi');",
             "ftp://ftp.example.com"
           ]
  end

  test "handles HTML with no links" do
    html = "<html><head><title>No links</title></head><body><p>Hello</p></body></html>"
    {:ok, document} = Document.load("https://example.com", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.raw == []
    assert data.links.http.internal == []
    assert data.links.http.external == []
    assert data.links.non_http == []
  end

  test "handles empty HTML body" do
    html = "<html><head></head><body></body></html>"
    {:ok, document} = Document.load("https://example.com", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.raw == []
  end

  test "deduplicates identical links" do
    html = """
    <html><body>
      <a href="/page">Link 1</a>
      <a href="/page">Link 2</a>
      <a href="/page">Link 3</a>
    </body></html>
    """

    {:ok, document} = Document.load("https://example.com", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.raw == ["/page"]
    assert data.links.http.internal == ["https://example.com/page"]
  end

  test "trims whitespace from link hrefs" do
    html = """
    <html><body>
      <a href="  /page  ">Padded link</a>
    </body></html>
    """

    {:ok, document} = Document.load("https://example.com", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.raw == ["/page"]
  end

  test "handles anchor-only links as internal" do
    html = """
    <html><body>
      <a href="#section">Anchor</a>
    </body></html>
    """

    {:ok, document} = Document.load("https://example.com/page", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.raw == ["#section"]
    assert data.links.http.internal == ["https://example.com/page#section"]
  end

  test "handles links with empty href" do
    html = """
    <html><body>
      <a href="">Empty href</a>
    </body></html>
    """

    {:ok, document} = Document.load("https://example.com/page", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.links.raw == [""]
    assert data.links.http.internal == ["https://example.com/page"]
  end

  test "handles absolutifying relative base href" do
    html = """
    <html><head><base href="/base/"></head><body>
      <a href="page">A page</a>
    </body></html>
    """

    {:ok, document} = Document.load("https://example.com/dir/", html)
    {:ok, %Document{data: data}} = PageScraper.scrape(document)

    assert data.urls.base == "https://example.com/base/"
    assert data.links.http.internal == ["https://example.com/base/page"]
  end
end
