defmodule Funkspector.PageScraperIntegrationTest do
  @moduledoc """
  End-to-end coverage of `Funkspector.page_scrape/2` against real HTML.

  Assertions test *shape* — non-empty lists of URLs that pass
  `Funkspector.Utils.valid_url?/1` — rather than specific link counts
  or strings, so the suite is resilient to upstream HTML changes.
  """

  use ExUnit.Case, async: true

  import FunkspectorTest.IntegrationUrls
  import Funkspector.Utils, only: [valid_url?: 1]

  @moduletag :integration
  @moduletag timeout: 60_000

  describe "github.com" do
    test "extracts internal and external links of valid shape" do
      assert {:ok, document} = Funkspector.page_scrape(github_https())

      internal = document.data.links.http.internal
      external = document.data.links.http.external

      assert is_list(internal) and internal != []
      assert is_list(external) and external != []

      assert Enum.all?(internal, &is_binary/1)
      assert Enum.all?(external, &is_binary/1)
      assert Enum.all?(internal, &valid_url?/1)
      assert Enum.all?(external, &valid_url?/1)
    end
  end

  describe "rocketvalidator.com" do
    test "extracts links of valid shape from the home page" do
      assert {:ok, document} = Funkspector.page_scrape(rocketvalidator())

      assert document.url =~ "rocketvalidator.com"

      internal = document.data.links.http.internal
      external = document.data.links.http.external

      assert is_list(internal) and internal != []
      assert is_list(external)

      assert Enum.all?(internal, &valid_url?/1)
      assert Enum.all?(external, &valid_url?/1)
    end
  end

  describe "canonical URL extraction" do
    test "picks up <link rel=canonical> from a hex.pm package page" do
      # hex.pm package pages render <link rel=canonical>; the home page
      # does not. We use a package page so the canonical-extraction path
      # in PageScraper is exercised against a real response (real headers,
      # real gzip, real CDN).
      assert {:ok, document} = Funkspector.page_scrape(hex_pm_package())

      canonical = document.data.urls.canonical

      if is_binary(canonical) do
        assert valid_url?(canonical)
        assert canonical =~ "hex.pm"
      else
        flunk(
          "Expected hex.pm package page to expose a <link rel=canonical>; " <>
            "got #{inspect(canonical)}. If hex.pm changed, pick another " <>
            "stable URL with a canonical tag."
        )
      end
    end
  end

  describe "basic auth gating" do
    test "scrapes a page protected by HTTP Basic Auth when credentials are provided" do
      url = httpbin_basic_auth("user", "passwd")

      assert {:ok, document} =
               with_transient_retry(fn ->
                 Funkspector.page_scrape(url, %{basic_auth: {"user", "passwd"}})
               end)

      assert document.url == url
      # httpbin returns a tiny JSON body, not full HTML — Floki parses any
      # binary, and the scraper should produce empty link lists rather than
      # crashing on the non-HTML payload.
      assert is_list(document.data.links.http.internal)
      assert is_list(document.data.links.http.external)
    end

    test "returns an error when basic auth fails" do
      url = httpbin_basic_auth("user", "passwd")

      assert {:error, ^url, %{status_code: 401}} =
               with_transient_retry(fn ->
                 Funkspector.page_scrape(url, %{basic_auth: {"user", "wrong"}})
               end)
    end
  end
end
