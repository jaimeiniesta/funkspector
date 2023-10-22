defmodule Funkspector.DocumentTest do
  use ExUnit.Case

  alias Funkspector.Document

  import Mock
  import FunkspectorTest.MockedConnections

  @url "http://example.com/page"
  @html "<html></html>"

  describe "request" do
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
  end

  describe "load" do
    test "requires an URL" do
      assert Document.load(nil, @html) == {:error, :url_required}
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
  end
end
