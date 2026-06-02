defmodule Funkspector.SitemapIntegrationTest do
  @moduledoc """
  End-to-end coverage of `Funkspector.sitemap_scrape/2` and
  `Funkspector.text_sitemap_scrape/2` against real sitemaps.

  The same Rocket Validator URLs are exercised by doctests in
  `lib/funkspector.ex:75-79` and `lib/funkspector.ex:99-103`, but the
  doctests can only assert one or two lines. Here we make richer
  assertions on the structure of the extracted `data.locs` and
  `data.lines` lists.
  """

  use ExUnit.Case, async: true

  import FunkspectorTest.IntegrationUrls
  import Funkspector.Utils, only: [valid_url?: 1]

  @moduletag :integration
  @moduletag timeout: 60_000

  describe "XML sitemap" do
    test "extracts a non-empty list of absolute, valid URLs" do
      assert {:ok, document} = Funkspector.sitemap_scrape(rocketvalidator_xml_sitemap())

      locs = document.data.locs

      assert is_list(locs)
      assert locs != []
      assert Enum.all?(locs, &is_binary/1)
      assert Enum.all?(locs, &valid_url?/1)

      # All locs should be absolute (start with http:// or https://).
      assert Enum.all?(locs, &String.starts_with?(&1, "http"))
    end
  end

  describe "text sitemap" do
    test "extracts a non-empty list of lines containing valid URLs" do
      assert {:ok, document} = Funkspector.text_sitemap_scrape(rocketvalidator_text_sitemap())

      lines = document.data.lines

      assert is_list(lines)
      assert lines != []
      assert Enum.all?(lines, &is_binary/1)

      # Every non-blank line in a well-formed text sitemap should be a URL.
      # We filter out any blank lines defensively in case the upstream
      # format ever changes whitespace conventions.
      non_blank = Enum.reject(lines, &(String.trim(&1) == ""))
      assert non_blank != []
      assert Enum.all?(non_blank, &valid_url?/1)
    end
  end
end
