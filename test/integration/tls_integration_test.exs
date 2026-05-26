defmodule Funkspector.TLSIntegrationTest do
  @moduledoc """
  TLS-specific behaviors against real hosts.

  These are the tests most likely to detect regressions from the hackney
  upgrade. Funkspector defaults to `hackney: [:insecure]` (see
  `Funkspector` default_options at `lib/funkspector.ex:117`), which means
  cert chain verification is disabled. The badssl.com hosts below are
  precisely the cases that would fail if that default ever silently
  flipped — exactly the kind of breakage hackney issue #501 produced.
  """

  use ExUnit.Case, async: true

  import FunkspectorTest.IntegrationUrls

  @moduletag :integration
  @moduletag timeout: 60_000

  test "resolves a host with a valid certificate chain" do
    assert {:ok, _final_url, %{status_code: 200}} =
             with_transient_retry(fn -> Funkspector.resolve(httpbin_root()) end)
  end

  test "accepts a self-signed certificate (verify_none default)" do
    url = badssl_self_signed()
    assert {:ok, ^url, %{status_code: 200}} = Funkspector.resolve(url)
  end

  test "accepts an expired certificate (verify_none default)" do
    url = badssl_expired()
    assert {:ok, ^url, %{status_code: 200}} = Funkspector.resolve(url)
  end

  test "accepts a certificate whose CN does not match the host (verify_none default)" do
    url = badssl_wrong_host()
    assert {:ok, ^url, %{status_code: 200}} = Funkspector.resolve(url)
  end

  test "honors an explicit :ssl override (same code path the SSL retry uses)" do
    # The retry logic at resolver.ex:86-96 merges %{ssl: [versions: [:"tlsv1.2"]]}
    # into the options on TLS errors. Setting it manually exercises that exact
    # path on a successful request, so a regression in option-forwarding from
    # Funkspector → HTTPoison → hackney is caught here.
    assert {:ok, _final_url, %{status_code: 200}} =
             with_transient_retry(fn ->
               Funkspector.resolve(httpbin_root(), %{ssl: [versions: [:"tlsv1.2"]]})
             end)
  end
end
