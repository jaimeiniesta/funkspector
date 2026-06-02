defmodule FunkspectorTest.IntegrationUrls do
  @moduledoc """
  Stable URL helpers for the integration test suite.

  Centralizing every external host in one module keeps the integration
  tests resilient to upstream outages: if the httpbin host becomes flaky
  we swap `@httpbin_base` in one place and every test follows. We default
  to `httpbingo.org` (the actively-maintained go-httpbin reimplementation);
  `httpbin.io` and `httpbin.org` are drop-in alternatives. The same applies
  to `badssl.com` and to the handful of production sites we exercise.

  Functions are preferred over module attributes so call sites read as
  intent (`httpbin_status(404)`) and so we keep the freedom to compose
  URL parameters later without rippling through every test file.

  Assertions should reference the helpers (or host-neutral fragments like
  `"/get"`) rather than a literal host, so swapping `@httpbin_base` never
  breaks a test.
  """

  @httpbin_base "https://httpbingo.org"
  @badssl_base "badssl.com"

  ##############
  # httpbin.org
  ##############

  @doc "Returns a URL that responds with the given HTTP status code."
  def httpbin_status(code), do: "#{@httpbin_base}/status/#{code}"

  @doc "Returns a URL that issues `n` absolute 302 redirects before reaching `/get`."
  def httpbin_redirect(n), do: "#{@httpbin_base}/redirect/#{n}"

  @doc "Returns a URL that issues `n` relative 302 redirects before reaching `/get`."
  def httpbin_relative_redirect(n), do: "#{@httpbin_base}/relative-redirect/#{n}"

  @doc "Returns a URL that 302-redirects to the URL passed in `to`."
  def httpbin_redirect_to(to) do
    "#{@httpbin_base}/redirect-to?url=#{URI.encode_www_form(to)}&status_code=302"
  end

  @doc "Returns a URL whose body is gzip-encoded JSON describing the request."
  def httpbin_gzip, do: "#{@httpbin_base}/gzip"

  @doc "Returns a URL whose body is deflate-encoded JSON describing the request."
  def httpbin_deflate, do: "#{@httpbin_base}/deflate"

  @doc "Returns a URL gated by HTTP Basic Auth with the given credentials."
  def httpbin_basic_auth(user, pass), do: "#{@httpbin_base}/basic-auth/#{user}/#{pass}"

  @doc "Returns a URL whose JSON response echoes the request's User-Agent header."
  def httpbin_user_agent, do: "#{@httpbin_base}/user-agent"

  @doc "Returns a URL whose JSON response echoes the request headers."
  def httpbin_headers, do: "#{@httpbin_base}/headers"

  @doc "Returns a URL whose body is a UTF-8 encoded HTML document."
  def httpbin_encoding_utf8, do: "#{@httpbin_base}/encoding/utf8"

  @doc """
  The httpbin.org root URL.

  Used by the TLS and resolver suites as a known-stable HTTPS endpoint with
  a valid certificate chain. Preferred over production sites for tests
  whose only requirement is "a 200 over TLS" — keeps the brittleness
  surface concentrated on a single host we already trust elsewhere.
  """
  def httpbin_root, do: "#{@httpbin_base}/"

  @doc "A minimal httpbin endpoint that returns 200 with a small JSON body."
  def httpbin_get, do: "#{@httpbin_base}/get"

  ##########
  # badssl
  ##########

  @doc "Returns a URL served with a self-signed TLS certificate."
  def badssl_self_signed, do: "https://self-signed.#{@badssl_base}/"

  @doc "Returns a URL served with an expired TLS certificate."
  def badssl_expired, do: "https://expired.#{@badssl_base}/"

  @doc "Returns a URL served with a certificate whose CN does not match the host."
  def badssl_wrong_host, do: "https://wrong.host.#{@badssl_base}/"

  ########################
  # Production endpoints
  ########################

  @doc "Plain `http://` URL that 301-redirects to its `https://` equivalent."
  def github_http, do: "http://github.com"

  @doc "Canonical HTTPS GitHub home page."
  def github_https, do: "https://github.com/"

  @doc "Hex.pm home page, a known-stable HTTPS endpoint with a valid cert chain."
  def hex_pm, do: "https://hex.pm/"

  @doc "A hex.pm package page — package pages render a <link rel=canonical>."
  def hex_pm_package, do: "https://hex.pm/packages/funkspector"

  @doc "Rocket Validator home page — used by the page scraper integration tests."
  def rocketvalidator, do: "https://rocketvalidator.com/"

  @doc "Rocket Validator XML sitemap (also exercised as a doctest in `Funkspector`)."
  def rocketvalidator_xml_sitemap, do: "https://rocketvalidator.com/sitemap.xml"

  @doc "Rocket Validator text sitemap (also exercised as a doctest in `Funkspector`)."
  def rocketvalidator_text_sitemap, do: "https://rocketvalidator.com/sitemap.txt"

  @doc "Personal site referenced by the existing `Funkspector.page_scrape/2` doctest."
  def jaimeiniesta, do: "https://jaimeiniesta.com"

  @doc """
  A host that is guaranteed to fail DNS resolution.

  RFC 2606's reserved TLDs (`.invalid`, `.test`, `.example`) would be the
  natural fit, but `Funkspector.Utils.valid_url?/1` rejects any TLD not in
  the bundled IANA list — so the resolver would short-circuit with
  `:invalid_url` before ever attempting the lookup. We use a `.com` host
  with a sufficiently-improbable label instead: `.com` passes TLD
  validation, and the label is long/specific enough that it will not
  resolve.
  """
  def nonexistent_domain,
    do: "http://funkspector-integration-test-nonexistent-host-xyz123.com"

  ##########
  # Helpers
  ##########

  @doc """
  Calls `fun.()` and retries up to `attempts - 1` times if the result
  signals a transient upstream gateway failure (HTTP 502/503/504 or a
  TCP-level timeout). Returns the final result either way.

  This is meant for tests that exercise Funkspector against a known-flaky
  third-party endpoint (e.g. httpbin.org's awselb gateway). Funkspector
  itself does not — and should not — retry on 5xx, because callers
  depend on faithful error tuples. The retry only protects the test
  suite from infrastructure hiccups, not from real behavioral regressions:
  permanent statuses like 401/403/404 are propagated immediately.
  """
  def with_transient_retry(fun, attempts \\ 3) when is_function(fun, 0) and attempts >= 1 do
    case fun.() do
      result when attempts > 1 ->
        if transient?(result) do
          Process.sleep(500)
          with_transient_retry(fun, attempts - 1)
        else
          result
        end

      result ->
        result
    end
  end

  defp transient?({:error, _url, %{status_code: code}}) when code in [502, 503, 504], do: true
  defp transient?({:error, _url, %{reason: :timeout}}), do: true
  defp transient?({:error, _url, %{reason: :connect_timeout}}), do: true
  defp transient?(_), do: false
end
