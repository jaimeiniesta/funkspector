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
end
