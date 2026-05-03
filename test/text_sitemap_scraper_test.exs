defmodule TextSitemapScraperTest do
  use ExUnit.Case

  import FunkspectorTest.MockedConnections, only: [mocked_text: 0]

  alias Funkspector.{Document, TextSitemapScraper}

  setup do
    url = "https://example.com/sitemap.xml"
    txt = mocked_text()

    {:ok, document} = Document.load(url, txt)

    {:ok, url: url, txt: txt, document: document}
  end

  test "scrapes data", %{document: document} do
    {:ok, document} = TextSitemapScraper.scrape(document)

    assert document == %Document{
             url: "https://example.com/sitemap.xml",
             contents:
               "http://example.com/\nhttp://example.com/about\n\n/faqs\n\nhttp://docs.example.com\n",
             data: %{
               lines: [
                 "http://example.com/",
                 "http://example.com/about",
                 "https://example.com/faqs",
                 "http://docs.example.com"
               ],
               urls: %{
                 parsed: %{
                   scheme: "https",
                   authority: "example.com",
                   userinfo: nil,
                   host: "example.com",
                   port: 443,
                   path: "/sitemap.xml",
                   query: nil,
                   fragment: nil
                 },
                 root: "https://example.com/"
               }
             }
           }
  end

  test "handles empty text content" do
    {:ok, document} = Document.load("https://example.com/sitemap.txt", "")
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == []
  end

  test "handles whitespace-only content" do
    {:ok, document} = Document.load("https://example.com/sitemap.txt", "   \n  \n   ")
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == []
  end

  test "handles single URL" do
    {:ok, document} = Document.load("https://example.com/sitemap.txt", "https://example.com/page")
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == ["https://example.com/page"]
  end

  test "deduplicates URLs" do
    text = "/page\n/page\n/other\n"
    {:ok, document} = Document.load("https://example.com/sitemap.txt", text)
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == [
             "https://example.com/page",
             "https://example.com/other"
           ]
  end

  test "absolutifies relative URLs" do
    text = "/about\n/contact\n"
    {:ok, document} = Document.load("https://example.com/sitemap.txt", text)
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == [
             "https://example.com/about",
             "https://example.com/contact"
           ]
  end

  test "trims whitespace from URLs" do
    text = "  /about  \n  /contact  \n"
    {:ok, document} = Document.load("https://example.com/sitemap.txt", text)
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == [
             "https://example.com/about",
             "https://example.com/contact"
           ]
  end

  test "skips blank lines between URLs" do
    text = "/page1\n\n\n/page2\n\n"
    {:ok, document} = Document.load("https://example.com/sitemap.txt", text)
    {:ok, %Document{data: data}} = TextSitemapScraper.scrape(document)

    assert data.lines == [
             "https://example.com/page1",
             "https://example.com/page2"
           ]
  end
end
