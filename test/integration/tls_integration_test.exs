defmodule Funkspector.TLSIntegrationTest do
  @moduledoc """
  TLS-specific behaviors against real hosts.

  Since v2.0.0 Funkspector verifies TLS certificates by default (see
  `Funkspector` `default_options/0`). The badssl.com hosts below — self
  signed, expired, and wrong-host certificates — must therefore be
  *rejected* by default, and only accepted when the caller explicitly opts
  out with `%{insecure: true}`. These are the tests most likely to detect a
  regression that silently re-disables verification.
  """

  use ExUnit.Case, async: true

  import FunkspectorTest.IntegrationUrls

  @moduletag :integration
  @moduletag timeout: 60_000

  test "resolves a host with a valid certificate chain" do
    assert {:ok, _final_url, %{status_code: 200}} =
             with_transient_retry(fn -> Funkspector.resolve(httpbin_root()) end)
  end

  test "rejects a self-signed certificate by default" do
    url = badssl_self_signed()
    assert {:error, ^url, _reason} = Funkspector.resolve(url)
  end

  test "rejects an expired certificate by default" do
    url = badssl_expired()
    assert {:error, ^url, _reason} = Funkspector.resolve(url)
  end

  test "rejects a certificate whose CN does not match the host by default" do
    url = badssl_wrong_host()
    assert {:error, ^url, _reason} = Funkspector.resolve(url)
  end

  test "accepts a self-signed certificate when insecure: true" do
    url = badssl_self_signed()
    assert {:ok, ^url, %{status_code: 200}} = Funkspector.resolve(url, %{insecure: true})
  end

  test "accepts an expired certificate when insecure: true" do
    url = badssl_expired()
    assert {:ok, ^url, %{status_code: 200}} = Funkspector.resolve(url, %{insecure: true})
  end

  test "accepts a wrong-host certificate when insecure: true" do
    url = badssl_wrong_host()
    assert {:ok, ^url, %{status_code: 200}} = Funkspector.resolve(url, %{insecure: true})
  end

  test "honors an explicit :ssl override (same code path the SSL retry uses)" do
    # The retry logic in Funkspector.Resolver merges %{ssl: [versions: [:"tlsv1.2"]]}
    # into the options on TLS errors. Setting it manually exercises that exact
    # path on a successful request, so a regression in option-forwarding from
    # Funkspector → the active HTTP adapter (Req/HTTPoison) is caught here.
    assert {:ok, _final_url, %{status_code: 200}} =
             with_transient_retry(fn ->
               Funkspector.resolve(httpbin_root(), %{ssl: [versions: [:"tlsv1.2"]]})
             end)
  end
end
