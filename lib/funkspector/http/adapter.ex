defmodule Funkspector.HTTP.Adapter do
  @moduledoc """
  Behaviour for Funkspector HTTP adapters.

  An adapter performs a single GET request and returns either a
  `Funkspector.Response` or a `Funkspector.Error`. It is responsible for:

    * translating Funkspector options (`:user_agent`, `:basic_auth`,
      `:timeout`, `:recv_timeout`, `:ssl`) into its native form;
    * mapping its native error type onto a normalized
      `%Funkspector.Error{}` whose `:reason` follows the
      `gen_tcp`/`inet` vocabulary (`:nxdomain`, `:timeout`, `:closed`,
      `{:tls_alert, _}`, etc.);
    * disabling automatic redirect following — Funkspector's
      `Funkspector.Resolver` is the sole authority for redirects.

  Two built-in adapters ship with Funkspector:

    * `Funkspector.HTTP.Adapters.Req` (default) — uses Req on top of
      Finch/Mint; not exposed to the hackney 1.x CVEs since hackney is not
      involved.
    * `Funkspector.HTTP.Adapters.HTTPoison` (opt-in) — wraps the
      historical `HTTPoison`/`hackney 1.21` stack.

  Select an adapter through application config or per-call options:

      # config/config.exs
      config :funkspector, :http_adapter, Funkspector.HTTP.Adapters.HTTPoison

      # or per call
      Funkspector.resolve(url, %{adapter: Funkspector.HTTP.Adapters.HTTPoison})
  """

  @callback get(url :: String.t(), opts :: map()) ::
              {:ok, Funkspector.Response.t()} | {:error, Funkspector.Error.t()}
end
