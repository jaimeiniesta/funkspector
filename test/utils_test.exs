defmodule UtilsTest do
  use ExUnit.Case

  doctest Funkspector.Utils

  alias Funkspector.Utils

  describe "absolutify/2 with a list" do
    test "returns empty list for empty input" do
      assert Utils.absolutify([], "https://example.com") == []
    end

    test "absolutifies relative paths" do
      links = ["/about", "/contact"]

      assert Utils.absolutify(links, "https://example.com") == [
               "https://example.com/about",
               "https://example.com/contact"
             ]
    end

    test "preserves absolute URLs" do
      links = ["https://other.com/page"]
      assert Utils.absolutify(links, "https://example.com") == ["https://other.com/page"]
    end

    test "handles URLs with query parameters" do
      links = ["/search?q=test&page=2"]

      assert Utils.absolutify(links, "https://example.com") == [
               "https://example.com/search?q=test&page=2"
             ]
    end

    test "handles URLs with fragments" do
      links = ["/page#section"]

      assert Utils.absolutify(links, "https://example.com") == [
               "https://example.com/page#section"
             ]
    end

    test "resolves relative to base URL path" do
      assert Utils.absolutify(["page"], "https://example.com/dir/") == [
               "https://example.com/dir/page"
             ]
    end
  end

  describe "absolutify/2 with a single string" do
    test "absolutifies a relative URL" do
      assert Utils.absolutify("/about", "https://example.com") == "https://example.com/about"
    end

    test "preserves an absolute URL" do
      assert Utils.absolutify("https://other.com", "https://example.com") == "https://other.com"
    end
  end

  describe "valid_url?/1 schemes" do
    test "accepts http and https" do
      assert Utils.valid_url?("http://example.com")
      assert Utils.valid_url?("https://example.com")
    end

    test "scheme matching is case-insensitive" do
      assert Utils.valid_url?("HTTP://example.com")
      assert Utils.valid_url?("HTTPS://example.com")
      assert Utils.valid_url?("Https://example.com")
    end

    test "rejects non-http schemes" do
      refute Utils.valid_url?("ftp://example.com")
      refute Utils.valid_url?("file:///etc/passwd")
      refute Utils.valid_url?("mailto:user@example.com")
      refute Utils.valid_url?("javascript:alert(1)")
      refute Utils.valid_url?("data:text/plain,hello")
      refute Utils.valid_url?("ws://example.com")
    end

    test "rejects URLs without a scheme" do
      refute Utils.valid_url?("example.com")
      refute Utils.valid_url?("//example.com")
      refute Utils.valid_url?("/path/only")
    end
  end

  describe "valid_url?/1 hosts" do
    test "accepts hosts with a valid IANA TLD" do
      assert Utils.valid_url?("https://example.com")
      assert Utils.valid_url?("https://example.org")
      assert Utils.valid_url?("https://example.io")
      assert Utils.valid_url?("https://example.museum")
      assert Utils.valid_url?("https://example.travel")
    end

    test "TLD matching is case-insensitive" do
      assert Utils.valid_url?("https://example.COM")
      assert Utils.valid_url?("https://example.Org")
    end

    test "accepts subdomains at any depth" do
      assert Utils.valid_url?("https://sub.example.com")
      assert Utils.valid_url?("https://a.b.c.d.example.com")
    end

    test "accepts internationalized domain names with ASCII TLDs" do
      assert Utils.valid_url?("https://ñandú.com")
      assert Utils.valid_url?("https://ejemplo.ñandú.com")
      assert Utils.valid_url?("https://münchen.de")
    end

    test "accepts localhost" do
      assert Utils.valid_url?("http://localhost")
      assert Utils.valid_url?("http://localhost:3000")
      assert Utils.valid_url?("http://localhost/path")
    end

    test "accepts IPv4 addresses" do
      assert Utils.valid_url?("http://127.0.0.1")
      assert Utils.valid_url?("http://192.168.1.1:8080")
      assert Utils.valid_url?("http://10.0.0.1/admin")
    end

    test "accepts IPv6 addresses" do
      assert Utils.valid_url?("http://[::1]")
      assert Utils.valid_url?("http://[::1]:8080")
      assert Utils.valid_url?("http://[2001:db8::1]/path")
    end

    test "rejects URLs without a host" do
      refute Utils.valid_url?("http://")
      refute Utils.valid_url?("https://")
      refute Utils.valid_url?("https:///path")
    end

    test "rejects single-label non-localhost hosts" do
      refute Utils.valid_url?("http://example")
      refute Utils.valid_url?("http://internal-server")
    end

    test "rejects hosts with TLDs not in the IANA list" do
      refute Utils.valid_url?("https://example.x")
      refute Utils.valid_url?("https://example.c")
      refute Utils.valid_url?("https://example.zzzz")
      refute Utils.valid_url?("https://example.abcdef")
    end

    test "rejects URLs with valid TLD followed by garbage segments (fix-14)" do
      refute Utils.valid_url?("https://example.com.ñ")
      refute Utils.valid_url?("https://example.com.ññ")
    end

    test "rejects stray digits between TLD and port or path (fix-15)" do
      refute Utils.valid_url?("https://example.com8080")
      refute Utils.valid_url?("https://example.com8080:443")
      refute Utils.valid_url?("https://example.com12345/path")
    end
  end

  describe "valid_url?/1 ports" do
    test "accepts common ports" do
      assert Utils.valid_url?("http://example.com:80")
      assert Utils.valid_url?("https://example.com:443")
      assert Utils.valid_url?("http://example.com:8080")
      assert Utils.valid_url?("http://example.com:3000")
    end

    test "accepts port boundaries" do
      assert Utils.valid_url?("http://example.com:1")
      assert Utils.valid_url?("http://example.com:65535")
    end

    test "accepts ports combined with paths and queries" do
      assert Utils.valid_url?("http://example.com:8080/path?q=1")
    end
  end

  describe "valid_url?/1 paths" do
    test "accepts no path" do
      assert Utils.valid_url?("https://example.com")
    end

    test "accepts root path" do
      assert Utils.valid_url?("https://example.com/")
    end

    test "accepts nested paths" do
      assert Utils.valid_url?("https://example.com/a/b/c")
      assert Utils.valid_url?("https://example.com/very/deeply/nested/path")
    end

    test "accepts paths with relative segments" do
      assert Utils.valid_url?("https://example.com/a/../b")
      assert Utils.valid_url?("https://example.com/./page")
    end

    test "accepts percent-encoded paths" do
      assert Utils.valid_url?("https://example.com/page%20with%20space")
      assert Utils.valid_url?("https://example.com/%E4%B8%AD%E6%96%87")
    end

    test "rejects paths containing literal whitespace" do
      refute Utils.valid_url?("https://example.com/path with space")
    end

    test "rejects URLs containing newlines or tabs" do
      refute Utils.valid_url?("https://example.com/path\nfoo")
      refute Utils.valid_url?("https://example.com/path\tfoo")
    end
  end

  describe "valid_url?/1 query strings" do
    test "accepts no query" do
      assert Utils.valid_url?("https://example.com/")
    end

    test "accepts an empty query" do
      assert Utils.valid_url?("https://example.com/?")
    end

    test "accepts a single parameter" do
      assert Utils.valid_url?("https://example.com/?q=1")
    end

    test "accepts multiple parameters" do
      assert Utils.valid_url?("https://example.com/?a=1&b=2&c=3")
    end

    test "accepts empty values" do
      assert Utils.valid_url?("https://example.com/?a=&b=")
    end

    test "accepts percent-encoded values" do
      assert Utils.valid_url?("https://example.com/?q=hello%20world")
    end
  end

  describe "valid_url?/1 fragments" do
    test "accepts no fragment" do
      assert Utils.valid_url?("https://example.com/")
    end

    test "accepts an empty fragment" do
      assert Utils.valid_url?("https://example.com/#")
    end

    test "accepts a text fragment" do
      assert Utils.valid_url?("https://example.com/#section-2")
    end

    test "accepts an encoded fragment" do
      assert Utils.valid_url?("https://example.com/#a%20b")
    end
  end

  describe "valid_url?/1 userinfo" do
    test "accepts URLs with user only" do
      assert Utils.valid_url?("https://user@example.com")
    end

    test "accepts URLs with user and password" do
      assert Utils.valid_url?("https://user:pass@example.com")
    end

    test "accepts userinfo combined with port and path" do
      assert Utils.valid_url?("https://user:pass@example.com:8080/path")
    end
  end

  describe "valid_url?/1 combined" do
    test "accepts a fully-featured URL" do
      assert Utils.valid_url?("https://user:pass@sub.example.com:8080/a/b?q=1&r=2#frag")
    end
  end

  describe "valid_url?/1 type guards" do
    test "rejects non-binary values" do
      refute Utils.valid_url?(nil)
      refute Utils.valid_url?(123)
      refute Utils.valid_url?(:atom)
      refute Utils.valid_url?([])
      refute Utils.valid_url?(~c"http://example.com")
      refute Utils.valid_url?(%{})
    end
  end

  describe "valid_url?/1 malformed input" do
    test "rejects empty and whitespace-only strings" do
      refute Utils.valid_url?("")
      refute Utils.valid_url?("   ")
      refute Utils.valid_url?("\n")
    end

    test "rejects non-URL text" do
      refute Utils.valid_url?("not a url")
      refute Utils.valid_url?("just some words")
    end

    test "rejects URLs with leading or trailing whitespace" do
      refute Utils.valid_url?(" https://example.com")
      refute Utils.valid_url?("https://example.com ")
    end
  end

  @tag :integration
  test "bundled IANA TLD list matches the live one" do
    %{status_code: 200, body: body} =
      HTTPoison.get!("https://data.iana.org/TLD/tlds-alpha-by-domain.txt")

    live =
      body
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    bundled =
      "priv/tlds-alpha-by-domain.txt"
      |> File.read!()
      |> String.split("\n", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "#"))
      |> Enum.map(&String.downcase/1)
      |> MapSet.new()

    assert live == bundled,
           "Bundled TLD list is out of sync with IANA. Refresh priv/tlds-alpha-by-domain.txt."
  end
end
