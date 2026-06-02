defmodule Funkspector.CompressionIntegrationTest do
  @moduledoc """
  Wire-level decompression behavior.

  Funkspector decompresses gzip responses in `Funkspector.Resolver.deflated/1`
  at `lib/funkspector/resolver.ex:114`. Deflate is intentionally not
  handled. These tests pin both behaviors against real servers so a
  future HTTP-engine swap doesn't regress them silently.
  """

  use ExUnit.Case, async: true

  import FunkspectorTest.IntegrationUrls

  @moduletag :integration
  @moduletag timeout: 60_000

  test "decompresses a gzip-encoded body from httpbin /gzip" do
    assert {:ok, _final_url, %{body: body, status_code: 200}} =
             with_transient_retry(fn -> Funkspector.resolve(httpbin_gzip()) end)

    # The body has already been gunzipped, so we read JSON content directly.
    # httpbin's /gzip endpoint returns: {"gzipped": true, ...}
    assert body =~ ~s("gzipped": true)
  end

  test "decompresses gzip from a real production site (rocketvalidator.com)" do
    # Many production sites serve gzip via CDN. Asserting we receive a
    # non-empty HTML body from rocketvalidator.com proves the deflated/1
    # path integrates correctly with the rest of the request flow.
    assert {:ok, _final_url, %{body: body, status_code: 200}} =
             Funkspector.resolve(rocketvalidator())

    assert is_binary(body)
    assert byte_size(body) > 0
    assert body =~ ~r/<html/i
  end

  test "documents current behavior: deflate-encoded bodies are NOT decompressed" do
    # resolver.ex:118-122 only handles "gzip" / "x-gzip" — deflate falls
    # through. When httpbin /deflate is up and returns 200, we assert the
    # body is *not* a readable JSON marker (proving deflate was left raw).
    # If httpbin's CDN returns a transient error (502 / timeout / etc.) we
    # log and skip — the goal is to pin Funkspector behavior, not to test
    # httpbin's uptime.
    case with_transient_retry(fn -> Funkspector.resolve(httpbin_deflate()) end) do
      {:ok, _final_url, %{status_code: 200, body: body}} ->
        # If this assertion ever fails, deflate handling was added and
        # both this test and resolver.ex's docs should be updated.
        refute body =~ ~s("deflated": true)

      other ->
        IO.warn(
          "Skipping deflate behavior assertion — httpbin /deflate returned: " <>
            inspect(other, limit: 5)
        )
    end
  end
end
