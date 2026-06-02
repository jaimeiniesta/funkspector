if Code.ensure_loaded?(HTTPoison) do
  defmodule Funkspector.HTTP.Adapters.HTTPoison do
    @moduledoc """
    Opt-in Funkspector HTTP adapter, backed by
    [HTTPoison](https://hex.pm/packages/httpoison) on top of hackney.

    Compiled only when the `:httpoison` dependency is actually present in the
    consuming project — `httpoison` is declared `optional: true` in
    `funkspector`'s `mix.exs`, so projects that stick with the default Req
    adapter do not need to pull it in. When HTTPoison is missing the module
    is simply not defined; selecting it as the adapter in that case fails
    with `UndefinedFunctionError` at call time, which is the desired
    behaviour for an explicit opt-in.

    This is the historical Funkspector HTTP path, preserved for users who
    cannot — or do not want to — move to Req yet. Like the Req adapter, it
    verifies TLS certificates by default; pass `insecure: true` (folded into
    hackney's native `:insecure` flag) to opt out. `:user_agent`,
    `:basic_auth`, `:ssl`, `:timeout`, `:recv_timeout`, and `:max_body_size`
    are honored.

    Errors from HTTPoison/hackney are translated to `%Funkspector.Error{}`
    so the rest of the pipeline does not see adapter-specific structs.

    Activate via application config or per-call options:

        config :funkspector, :http_adapter, Funkspector.HTTP.Adapters.HTTPoison

        Funkspector.resolve(url, %{adapter: Funkspector.HTTP.Adapters.HTTPoison})

    > #### Security note {: .warning}
    > hackney 1.21 is affected by
    > [CVE-2026-47075](https://nvd.nist.gov/vuln/detail/CVE-2026-47075) (CRLF
    > injection / request splitting) and
    > [CVE-2026-47076](https://nvd.nist.gov/vuln/detail/CVE-2026-47076) (SSRF
    > via URL normalization), both fixed in hackney 4.0.1. HTTPoison's
    > `~> 1.21` constraint cannot reach that fix
    > ([httpoison#501](https://github.com/edgurgel/httpoison/issues/501)), so
    > prefer the default Req adapter for new integrations.
    """

    @behaviour Funkspector.HTTP.Adapter

    alias Funkspector.{Response, Error}

    @impl true
    def get(url, opts) when is_map(opts) do
      {headers, request_options} = request_headers_and_options(opts)

      max_body_size = opts[:max_body_size]

      case HTTPoison.get(url, headers, Map.to_list(request_options)) do
        {:ok, %HTTPoison.Response{status_code: status, headers: response_headers, body: body}} ->
          build_response(url, status, response_headers, body, max_body_size)

        {:ok, %{status_code: status, headers: response_headers, body: body}} ->
          build_response(url, status, response_headers, body, max_body_size)

        {:ok, %{status_code: status, headers: response_headers}} ->
          build_response(url, status, response_headers, nil, max_body_size)

        {:error, %HTTPoison.Error{reason: reason}} ->
          {:error, %Error{reason: reason, adapter: __MODULE__}}

        {:error, %{reason: reason}} ->
          {:error, %Error{reason: reason, adapter: __MODULE__}}

        {:error, reason} ->
          {:error, %Error{reason: reason, adapter: __MODULE__}}
      end
    end

    defp build_response(url, status, headers, body, max_body_size) do
      if within_limit?(body, max_body_size) do
        {:ok, %Response{status_code: status, headers: headers, body: body, request_url: url}}
      else
        {:error, %Error{reason: :body_too_large, adapter: __MODULE__}}
      end
    end

    defp within_limit?(nil, _limit), do: true
    defp within_limit?(_body, nil), do: true
    defp within_limit?(_body, :infinity), do: true
    defp within_limit?(body, limit) when is_integer(limit), do: byte_size(body) <= limit

    defp request_headers_and_options(options) do
      headers = request_headers(options)

      options =
        options
        |> translate_insecure()
        |> Map.delete(:user_agent)
        |> Map.delete(:basic_auth)
        |> Map.delete(:adapter)
        |> Map.delete(:contents)
        |> Map.delete(:connect_options)
        |> Map.delete(:insecure)

      {headers, options}
    end

    # `insecure: true` disables hackney's certificate verification, mirroring the
    # Req adapter. It is folded into the `:hackney` option list (hackney's native
    # `:insecure` flag) so explicit `:hackney` opts the caller passed are kept.
    defp translate_insecure(%{insecure: true} = options) do
      hackney = Enum.uniq([:insecure | Map.get(options, :hackney, [])])
      Map.put(options, :hackney, hackney)
    end

    defp translate_insecure(options), do: options

    defp request_headers(options) do
      headers = [{"User-Agent", options[:user_agent]}]

      case options[:basic_auth] do
        {username, password} ->
          auth = Base.encode64("#{username}:#{password}")
          [{"Authorization", "Basic #{auth}"} | headers]

        _ ->
          headers
      end
    end
  end
end
