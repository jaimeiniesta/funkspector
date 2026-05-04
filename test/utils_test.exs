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

  describe "valid_url?/1" do
    test "returns true for valid HTTP URLs" do
      assert Utils.valid_url?("http://example.com")
      assert Utils.valid_url?("https://example.com")
      assert Utils.valid_url?("https://example.com/path")
      assert Utils.valid_url?("https://example.com/path?query=value")
      assert Utils.valid_url?("https://example.com:8080/path")
    end

    test "returns true for internationalized domain names" do
      assert Utils.valid_url?("https://ejemplo.ñandú.com")
      assert Utils.valid_url?("https://ñandú.com")
      assert Utils.valid_url?("https://münchen.de")
    end

    test "returns true for subdomains" do
      assert Utils.valid_url?("https://sub.example.com")
      assert Utils.valid_url?("https://a.b.c.example.com")
    end

    test "returns false for invalid TLDs" do
      refute Utils.valid_url?("https://example.x")
      refute Utils.valid_url?("https://example.c")
      refute Utils.valid_url?("https://example.ñ")
      refute Utils.valid_url?("https://example.ññ")
    end

    test "returns false when a valid TLD is followed by invalid trailing segments" do
      refute Utils.valid_url?("https://example.com.ñ")
      refute Utils.valid_url?("https://example.com.ññ")
      refute Utils.valid_url?("https://example.abcdef")
    end

    test "returns false when stray digits appear between TLD and port or path" do
      refute Utils.valid_url?("https://example.com8080")
      refute Utils.valid_url?("https://example.com8080:443")
      refute Utils.valid_url?("https://example.com12345/path")
    end

    test "returns false for non-HTTP URLs" do
      refute Utils.valid_url?("ftp://example.com")
      refute Utils.valid_url?("mailto:user@example.com")
      refute Utils.valid_url?("javascript:alert(1)")
    end

    test "returns false for invalid formats" do
      refute Utils.valid_url?("not a url")
      refute Utils.valid_url?("http://")
      refute Utils.valid_url?("")
      refute Utils.valid_url?("   ")
    end

    test "returns false for non-binary values" do
      refute Utils.valid_url?(nil)
      refute Utils.valid_url?(123)
      refute Utils.valid_url?(:atom)
      refute Utils.valid_url?([])
    end

    @tag :integration
    test "returns true for all IANA TLDs" do
      %{status_code: 200, body: body} =
        HTTPoison.get!("https://data.iana.org/TLD/tlds-alpha-by-domain.txt")

      tlds =
        body
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))

      assert length(tlds) > 0

      for tld <- tlds do
        url = "http://example.#{String.downcase(tld)}"
        assert Utils.valid_url?(url), "Expected #{url} to be valid"
      end
    end
  end
end
