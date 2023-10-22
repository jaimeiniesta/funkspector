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
end
