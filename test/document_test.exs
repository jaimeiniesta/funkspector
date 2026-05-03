defmodule Funkspector.DocumentTest do
  use ExUnit.Case

  alias Funkspector.Document

  import Mock
  import FunkspectorTest.MockedConnections

  @url "http://example.com/page"

  @html "<html></html>"

  @invalid_urls [
    "Warning: Element name h2<audio< cannot be represented as XML 1.0.",
    nil,
    "   ",
    25
  ]

  describe "request" do
    test "validates URL" do
      for url <- @invalid_urls do
        assert Document.request(url) == {:error, url, :invalid_url}
      end
    end

    test "returns a Document with the contents retrieved from the given url" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> successful_response(200) end do
        assert Document.request(@url) ==
                 {:ok,
                  %Document{
                    url: @url,
                    contents: mocked_html(),
                    data: %{
                      urls: %{
                        original: @url,
                        parsed: %{
                          scheme: "http",
                          authority: "example.com",
                          userinfo: nil,
                          host: "example.com",
                          port: 80,
                          path: "/page",
                          query: nil,
                          fragment: nil
                        },
                        root: "http://example.com/"
                      },
                      headers: %{
                        "content-length" => "293427",
                        "content-type" => "text/html;charset=utf-8"
                      }
                    }
                  }}
      end
    end

    test "returns error for non-2xx response status" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> server_error_response(500) end do
        {:error, @url, response} = Document.request(@url)
        assert response.status_code == 500
      end
    end

    test "returns error for 403 forbidden" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> forbidden_response() end do
        {:error, @url, response} = Document.request(@url)
        assert response.status_code == 403
      end
    end

    test "returns error when host cannot be resolved" do
      with_mock HTTPoison, get: fn _url, _headers, _options -> http_error_response() end do
        assert Document.request(@url) ==
                 {:error, @url, %HTTPoison.Error{id: nil, reason: :nxdomain}}
      end
    end

    test "preserves original URL when following redirects" do
      with_mock HTTPoison, get: fn url, _headers, _options -> redirect_from(url) end do
        {:ok, document} = Document.request("http://example.com/redirect/1")
        assert document.url == "http://example.com/redirect/3"
        assert document.data.urls.original == "http://example.com/redirect/1"
      end
    end
  end

  describe "load" do
    test "validates URL" do
      for url <- @invalid_urls do
        assert Document.load(url, @html) == {:error, url, :invalid_url}
      end
    end

    test "returns a Document with the loaded contents and the given url" do
      assert Document.load(@url, @html) ==
               {:ok,
                %Document{
                  url: @url,
                  contents: @html,
                  data: %{
                    urls: %{
                      parsed: %{
                        scheme: "http",
                        authority: "example.com",
                        userinfo: nil,
                        host: "example.com",
                        port: 80,
                        path: "/page",
                        query: nil,
                        fragment: nil
                      },
                      root: "http://example.com/"
                    }
                  }
                }}
    end

    test "does not include original URL in loaded document" do
      {:ok, document} = Document.load(@url, @html)
      refute Map.has_key?(document.data.urls, :original)
    end

    test "does not include headers in loaded document" do
      {:ok, document} = Document.load(@url, @html)
      refute Map.has_key?(document.data, :headers)
    end

    test "parses URL with path and query" do
      url = "https://example.com/page?q=test"
      {:ok, document} = Document.load(url, @html)
      assert document.data.urls.parsed.path == "/page"
      assert document.data.urls.parsed.query == "q=test"
      assert document.data.urls.root == "https://example.com/"
    end
  end
end
