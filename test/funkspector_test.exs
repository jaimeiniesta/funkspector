defmodule FunkspectorTest do
  use ExUnit.Case

  doctest Funkspector

  import Mock
  import FunkspectorTest.MockedConnections

  alias Funkspector.Document

  @invalid_urls [
    "Warning: Element name h2<audio< cannot be represented as XML 1.0.",
    nil,
    "   ",
    25
  ]

  @html_doc """
  <html>
    <body>
      <a href="/faqs">FAQs</a>
    </body>
  </html>
  """

  @xml_doc """
  <?xml version="1.0" encoding="UTF-8"?>
  <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    <url>
      <loc>/faqs</loc>
    </url>
  </urlset>
  """

  @txt_doc """
  /faqs
  /terms
  """

  describe "page_scrape" do
    test "scrapes page if it exists" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> successful_response() end do
        {:ok, document} = Funkspector.page_scrape("https://example.com")

        assert document == %Document{
                 url: "https://example.com",
                 contents:
                   "<html>\n  <head>\n    <title>An example page</title>\n  </head>\n  <body>\n    <!-- Internal absolute links -->\n    <a href=\"http://example.com/\">Root</a>\n    <a href=\"http://example.com/faqs\">FAQs</a>\n    <a href=\"http://example.com/faqs\">FAQs (duplicate link that will be ignored)</a>\n    <a href=\"http://example.com/contact\">Contact</a>\n    <a href=\"https://example.com/secure.html\">Secure</a>\n\n    <!--\n    <a href=\"https://example.com/not-included.html\">Commented out should not be included</a>\n    -->\n\n    <!-- Internal relative links -->\n    <a href=\"/relative-1\">Relative 1, including root</a>\n    <a href=\"relative-2\">Relative 2, not including root</a>\n    <a href=\"relative-3?q=some#results\">Relative 3, with querystring and anchor</a>\n\n    <!-- External links -->\n    <a href=\"https://twitter.com\">Twitter</a>\n    <a href=\"https://github.com\">Github</a>\n    <a href=\"http://example.com.br\">Example BR</a>\n    <a href=\"http://example.com.mx/faqs\">Example MX</a>\n\n    <!-- Non-HTTP links -->\n    <a href=\"mailto:hello@example.com\">email</a>\n    <a href=\"javascript:alert('hi');\">hello</a>\n    <a href=\"ftp://ftp.example.com\">FTP</a>\n  </body>\n</html>\n",
                 data: %{
                   headers: %{
                     "content-length" => "293427",
                     "content-type" => "text/html;charset=utf-8"
                   },
                   links: %{
                     http: %{
                       external: [
                         "https://twitter.com",
                         "https://github.com",
                         "http://example.com.br",
                         "http://example.com.mx/faqs"
                       ],
                       internal: [
                         "http://example.com/",
                         "http://example.com/faqs",
                         "http://example.com/contact",
                         "https://example.com/secure.html",
                         "https://example.com/relative-1",
                         "https://example.com/relative-2",
                         "https://example.com/relative-3?q=some#results"
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
                   },
                   urls: %{
                     base: "https://example.com",
                     original: "https://example.com",
                     parsed: %{
                       scheme: "https",
                       authority: "example.com",
                       userinfo: nil,
                       host: "example.com",
                       port: 443,
                       path: nil,
                       query: nil,
                       fragment: nil
                     },
                     root: "https://example.com/",
                     canonical: nil
                   }
                 }
               }
      end
    end

    test "follows redirections" do
      with_mock HTTPoison, get: fn url, _headers, _options -> redirect_from(url) end do
        {:ok, document} = Funkspector.page_scrape("http://example.com/redirect/1")

        assert document == %Document{
                 contents:
                   "<html>\n  <head>\n    <title>An example page</title>\n  </head>\n  <body>\n    <!-- Internal absolute links -->\n    <a href=\"http://example.com/\">Root</a>\n    <a href=\"http://example.com/faqs\">FAQs</a>\n    <a href=\"http://example.com/faqs\">FAQs (duplicate link that will be ignored)</a>\n    <a href=\"http://example.com/contact\">Contact</a>\n    <a href=\"https://example.com/secure.html\">Secure</a>\n\n    <!--\n    <a href=\"https://example.com/not-included.html\">Commented out should not be included</a>\n    -->\n\n    <!-- Internal relative links -->\n    <a href=\"/relative-1\">Relative 1, including root</a>\n    <a href=\"relative-2\">Relative 2, not including root</a>\n    <a href=\"relative-3?q=some#results\">Relative 3, with querystring and anchor</a>\n\n    <!-- External links -->\n    <a href=\"https://twitter.com\">Twitter</a>\n    <a href=\"https://github.com\">Github</a>\n    <a href=\"http://example.com.br\">Example BR</a>\n    <a href=\"http://example.com.mx/faqs\">Example MX</a>\n\n    <!-- Non-HTTP links -->\n    <a href=\"mailto:hello@example.com\">email</a>\n    <a href=\"javascript:alert('hi');\">hello</a>\n    <a href=\"ftp://ftp.example.com\">FTP</a>\n  </body>\n</html>\n",
                 data: %{
                   headers: %{
                     "content-length" => "293427",
                     "content-type" => "text/html;charset=utf-8"
                   },
                   links: %{
                     http: %{
                       external: [
                         "https://twitter.com",
                         "https://github.com",
                         "http://example.com.br",
                         "http://example.com.mx/faqs"
                       ],
                       internal: [
                         "http://example.com/",
                         "http://example.com/faqs",
                         "http://example.com/contact",
                         "https://example.com/secure.html",
                         "http://example.com/relative-1",
                         "http://example.com/redirect/relative-2",
                         "http://example.com/redirect/relative-3?q=some#results"
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
                   },
                   urls: %{
                     base: "http://example.com/redirect/3",
                     original: "http://example.com/redirect/1",
                     parsed: %{
                       scheme: "http",
                       authority: "example.com",
                       userinfo: nil,
                       host: "example.com",
                       port: 80,
                       path: "/redirect/3",
                       query: nil,
                       fragment: nil
                     },
                     root: "http://example.com/",
                     canonical: nil
                   }
                 },
                 url: "http://example.com/redirect/3"
               }
      end
    end

    test "retuns error if page does not exist" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> http_error_response() end do
        assert Funkspector.page_scrape("https://example.com") ==
                 {:error, "https://example.com", %HTTPoison.Error{reason: :nxdomain, id: nil}}
      end
    end

    test "returns error if URL is invalid" do
      for url <- @invalid_urls do
        assert Funkspector.page_scrape(url) == {:error, url, :invalid_url}
        assert Funkspector.page_scrape(url, %{contents: @html_doc}) == {:error, url, :invalid_url}
      end
    end
  end

  describe "sitemap_scrape" do
    test "scrapes sitemap if it exists" do
      with_mock HTTPoison,
        get: fn _url, _headers, _options -> successful_response_for_sitemap() end do
        {:ok, document} = Funkspector.sitemap_scrape("https://example.com/sitemap.xml")

        assert document == %Document{
                 url: "https://example.com/sitemap.xml",
                 contents:
                   "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n   <url>\n      <loc>/</loc>\n   </url>\n   <url>\n      <loc>/faqs</loc>\n   </url>\n   <url>\n      <loc>/about</loc>\n   </url>\n   <!--\n   <url>\n      <loc>/commented-out-should-not-be-included</loc>\n   </url>\n   -->\n</urlset>\n",
                 data: %{
                   headers: %{
                     "content-length" => "293427",
                     "content-type" => "text/xml;charset=utf-8"
                   },
                   locs: [
                     "https://example.com/",
                     "https://example.com/faqs",
                     "https://example.com/about"
                   ],
                   urls: %{
                     original: "https://example.com/sitemap.xml",
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

    test "retuns error if page does not exist" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> http_error_response() end do
        assert Funkspector.sitemap_scrape("https://example.com/sitemap.xml") ==
                 {:error, "https://example.com/sitemap.xml",
                  %HTTPoison.Error{reason: :nxdomain, id: nil}}
      end
    end

    test "returns error if URL is invalid" do
      for url <- @invalid_urls do
        assert Funkspector.sitemap_scrape(url) == {:error, url, :invalid_url}

        assert Funkspector.sitemap_scrape(url, %{contents: @xml_doc}) ==
                 {:error, url, :invalid_url}
      end
    end
  end

  describe "text_sitemap_scrape" do
    test "scrapes text sitemap if it exists" do
      with_mock HTTPoison,
        get: fn _url, _headers, _options -> successful_response_for_text_sitemap() end do
        {:ok, document} = Funkspector.text_sitemap_scrape("https://example.com/sitemap.txt")

        assert document == %Document{
                 contents:
                   "http://example.com/\nhttp://example.com/about\n\n/faqs\n\nhttp://docs.example.com\n",
                 data: %{
                   headers: %{
                     "content-length" => "293427",
                     "content-type" => "text/plain;charset=utf-8"
                   },
                   urls: %{
                     original: "https://example.com/sitemap.txt",
                     parsed: %{
                       authority: "example.com",
                       fragment: nil,
                       host: "example.com",
                       path: "/sitemap.txt",
                       port: 443,
                       query: nil,
                       scheme: "https",
                       userinfo: nil
                     },
                     root: "https://example.com/"
                   },
                   lines: [
                     "http://example.com/",
                     "http://example.com/about",
                     "https://example.com/faqs",
                     "http://docs.example.com"
                   ]
                 },
                 url: "https://example.com/sitemap.txt"
               }
      end
    end

    test "retuns error if page does not exist" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> http_error_response() end do
        assert Funkspector.sitemap_scrape("https://example.com/sitemap.xml") ==
                 {:error, "https://example.com/sitemap.xml",
                  %HTTPoison.Error{reason: :nxdomain, id: nil}}
      end
    end

    test "returns error if URL is invalid" do
      for url <- @invalid_urls do
        assert Funkspector.text_sitemap_scrape(url) == {:error, url, :invalid_url}

        assert Funkspector.text_sitemap_scrape(url, %{contents: @txt_doc}) ==
                 {:error, url, :invalid_url}
      end
    end
  end

  describe "loading a document contents" do
    test "page_scrape" do
      {:ok, document} = Funkspector.page_scrape("https://example.com", %{contents: @html_doc})

      assert document == %Document{
               contents: "<html>\n  <body>\n    <a href=\"/faqs\">FAQs</a>\n  </body>\n</html>\n",
               data: %{
                 links: %{
                   http: %{external: [], internal: ["https://example.com/faqs"]},
                   non_http: [],
                   raw: ["/faqs"]
                 },
                 urls: %{
                   base: "https://example.com",
                   parsed: %{
                     scheme: "https",
                     authority: "example.com",
                     userinfo: nil,
                     host: "example.com",
                     port: 443,
                     path: nil,
                     query: nil,
                     fragment: nil
                   },
                   root: "https://example.com/",
                   canonical: nil
                 }
               },
               url: "https://example.com"
             }
    end

    test "sitemap_scrape" do
      {:ok, document} =
        Funkspector.sitemap_scrape("https://example.com/sitemap.xml", %{contents: @xml_doc})

      assert document == %Document{
               contents:
                 "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n  <url>\n    <loc>/faqs</loc>\n  </url>\n</urlset>\n",
               data: %{
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
                 },
                 locs: ["https://example.com/faqs"]
               },
               url: "https://example.com/sitemap.xml"
             }
    end

    test "text_sitemap_scrape" do
      {:ok, document} =
        Funkspector.text_sitemap_scrape("https://example.com/sitemap.txt", %{contents: @txt_doc})

      assert document == %Document{
               url: "https://example.com/sitemap.txt",
               contents: "/faqs\n/terms\n",
               data: %{
                 lines: ["https://example.com/faqs", "https://example.com/terms"],
                 urls: %{
                   parsed: %{
                     scheme: "https",
                     authority: "example.com",
                     userinfo: nil,
                     host: "example.com",
                     port: 443,
                     path: "/sitemap.txt",
                     query: nil,
                     fragment: nil
                   },
                   root: "https://example.com/"
                 }
               }
             }
    end
  end
end
