defmodule Funkspector.DocumentTest do
  use ExUnit.Case

  alias Funkspector.Document

  import Mock
  import FunkspectorTest.MockedConnections

  @url "http://example.com"
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
                      urls: %{original_url: @url},
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
    test "returns a Document with the loaded contents" do
      assert Document.load(@html) == {:ok, %Document{url: nil, contents: @html, data: nil}}
    end

    test "returns a Document with the loaded contents and the given url" do
      assert Document.load(@html, url: @url) ==
               {:ok, %Document{url: @url, contents: @html, data: nil}}
    end
  end
end
