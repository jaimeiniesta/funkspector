defmodule SitemapScraperTest do
  use ExUnit.Case

  import FunkspectorTest.MockedConnections, only: [mocked_xml: 0, malformed_xml: 0]

  alias Funkspector.{Document, SitemapScraper}

  setup do
    url = "https://example.com/sitemap.xml"
    xml = mocked_xml()

    {:ok, document} = Document.load(url, xml)

    {:ok, url: url, xml: xml, document: document}
  end

  test "scrapes data", %{document: document} do
    {:ok, document} = SitemapScraper.scrape(document)

    assert document == %Document{
             url: "https://example.com/sitemap.xml",
             contents:
               "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n   <url>\n      <loc>/</loc>\n   </url>\n   <url>\n      <loc>/faqs</loc>\n   </url>\n   <url>\n      <loc>/about</loc>\n   </url>\n   <!--\n   <url>\n      <loc>/commented-out-should-not-be-included</loc>\n   </url>\n   -->\n</urlset>\n",
             data: %{
               locs: [
                 "https://example.com/",
                 "https://example.com/faqs",
                 "https://example.com/about"
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

  test "returns no locs if the XML could not be parsed", %{url: url} do
    xml = malformed_xml()

    {:ok, document} = Document.load(url, xml)
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    assert data.locs == []
  end

  test "returns empty locs for empty XML sitemap" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    </urlset>
    """

    {:ok, document} = Document.load("https://example.com/sitemap.xml", xml)
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    assert data.locs == []
  end

  test "absolutifies relative locs", %{url: url} do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>/page1</loc></url>
      <url><loc>/page2</loc></url>
    </urlset>
    """

    {:ok, document} = Document.load(url, xml)
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    assert data.locs == [
             "https://example.com/page1",
             "https://example.com/page2"
           ]
  end

  test "deduplicates locs" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>/page</loc></url>
      <url><loc>/page</loc></url>
      <url><loc>/other</loc></url>
    </urlset>
    """

    {:ok, document} = Document.load("https://example.com/sitemap.xml", xml)
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    assert data.locs == [
             "https://example.com/page",
             "https://example.com/other"
           ]
  end

  test "handles XML with absolute URLs" do
    xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <url><loc>https://example.com/page1</loc></url>
      <url><loc>https://example.com/page2</loc></url>
    </urlset>
    """

    {:ok, document} = Document.load("https://example.com/sitemap.xml", xml)
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    assert data.locs == [
             "https://example.com/page1",
             "https://example.com/page2"
           ]
  end

  test "returns empty locs for completely empty content" do
    {:ok, document} = Document.load("https://example.com/sitemap.xml", "")
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    assert data.locs == []
  end

  test "ignores commented-out URLs", %{document: document} do
    {:ok, %Document{data: data}} = SitemapScraper.scrape(document)

    refute "https://example.com/commented-out-should-not-be-included" in data.locs
  end
end
