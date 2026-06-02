defmodule Funkspector.ResolverIntegrationTest do
  @moduledoc """
  End-to-end coverage of `Funkspector.Resolver.resolve/2` against real HTTP.

  These tests are the safety net for HTTP-engine-level changes (hackney
  upgrade, future Req adapter): they assert against real status codes,
  real redirect headers, real DNS errors and real basic auth challenges
  — the kinds of regressions that no mock can catch.

  Excluded from the default `mix test` run; opt in with `--include integration`.
  """

  use ExUnit.Case, async: true

  import FunkspectorTest.IntegrationUrls

  @moduletag :integration
  @moduletag timeout: 60_000

  describe "successful requests" do
    test "resolves a stable HTTPS endpoint to itself with a 200" do
      url = httpbin_get()

      assert {:ok, ^url, %{status_code: 200}} =
               with_transient_retry(fn -> Funkspector.resolve(url) end)
    end
  end

  describe "redirects" do
    test "upgrades http://github.com to https://github.com/" do
      assert {:ok, "https://github.com/", %{status_code: 200}} =
               Funkspector.resolve(github_http())
    end

    test "follows an absolute redirect chain of depth 3" do
      assert {:ok, final_url, %{status_code: 200}} =
               with_transient_retry(fn -> Funkspector.resolve(httpbin_redirect(3)) end)

      # /redirect/N terminates at /get on the httpbin host.
      assert final_url =~ "/get"
    end

    test "follows a relative redirect chain" do
      assert {:ok, final_url, %{status_code: 200}} =
               with_transient_retry(fn ->
                 Funkspector.resolve(httpbin_relative_redirect(2))
               end)

      assert final_url =~ "/get"
    end

    test "follows a cross-host redirect" do
      # example.com is a different host from the httpbin host, exercising the
      # cross-origin redirect path. (httpbingo's /redirect-to only allows a
      # small destination allowlist, of which example.com is a member.)
      assert {:ok, final_url, %{status_code: 200}} =
               with_transient_retry(fn ->
                 Funkspector.resolve(httpbin_redirect_to("https://example.com/"))
               end)

      assert final_url == "https://example.com/"
    end

    test "returns a too_many_redirects error past the max of 5 hops" do
      # /redirect/10 needs 10 hops; the resolver caps at 5 and returns an
      # explicit error tuple rather than a partially-followed chain.
      assert {:error, _url, :too_many_redirects} =
               with_transient_retry(fn -> Funkspector.resolve(httpbin_redirect(10)) end)
    end
  end

  describe "error responses" do
    test "returns an error tuple for a 404" do
      url = httpbin_status(404)

      assert {:error, ^url, %{status_code: 404}} =
               with_transient_retry(fn -> Funkspector.resolve(url) end)
    end

    test "returns an error tuple for a 403" do
      url = httpbin_status(403)

      assert {:error, ^url, %{status_code: 403}} =
               with_transient_retry(fn -> Funkspector.resolve(url) end)
    end

    test "returns an error tuple for a 500" do
      url = httpbin_status(500)
      # 500 is not in the transient set, so the retry helper returns it as-is.
      assert {:error, ^url, %{status_code: 500}} =
               with_transient_retry(fn -> Funkspector.resolve(url) end)
    end

    test "returns an error tuple for a 300 Multiple Choices" do
      url = httpbin_status(300)

      assert {:error, ^url, %{status_code: 300}} =
               with_transient_retry(fn -> Funkspector.resolve(url) end)
    end

    test "returns an error for a DNS lookup failure" do
      url = nonexistent_domain()
      assert {:error, ^url, error} = Funkspector.resolve(url)

      # We assert on the `:reason` field only — when migrating off HTTPoison
      # the struct module name will change but the reason atom is part of
      # the underlying gen_tcp/inet contract.
      assert %{reason: :nxdomain} = error
    end
  end

  describe "request headers" do
    test "sends the custom User-Agent through to the server" do
      user_agent = "Funkspector-IntegrationTest/1.0"

      assert {:ok, _final_url, %{body: body, status_code: 200}} =
               with_transient_retry(fn ->
                 Funkspector.resolve(httpbin_user_agent(), %{user_agent: user_agent})
               end)

      # httpbin's /user-agent endpoint returns JSON like {"user-agent": "..."}.
      assert body =~ user_agent
    end

    test "succeeds with valid HTTP Basic Auth credentials" do
      url = httpbin_basic_auth("user", "passwd")

      assert {:ok, ^url, %{status_code: 200}} =
               with_transient_retry(fn ->
                 Funkspector.resolve(url, %{basic_auth: {"user", "passwd"}})
               end)
    end

    test "returns 401 with invalid HTTP Basic Auth credentials" do
      url = httpbin_basic_auth("user", "passwd")

      assert {:error, ^url, %{status_code: 401}} =
               with_transient_retry(fn ->
                 Funkspector.resolve(url, %{basic_auth: {"user", "wrong"}})
               end)
    end
  end
end
