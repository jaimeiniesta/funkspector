defmodule Funkspector.HTTP.Adapters.Req do
  @moduledoc """
  Default Funkspector HTTP adapter, backed by [Req](https://hex.pm/packages/req)
  (Finch/Mint).

  Req does not depend on hackney, so this adapter is the recommended path
  for new code: it sidesteps the hackney 4.x CVE cluster
  (CVE-2026-47066..47076) that the legacy `HTTPoison`/`hackney 1.21` stack
  is still vulnerable to.

  Funkspector options are translated to Req options at the boundary:

    * `:user_agent`   → `User-Agent` header
    * `:basic_auth`   → `:auth` (basic)
    * `:timeout`      → `:connect_options[:timeout]`
    * `:recv_timeout` → `:receive_timeout`
    * `:ssl`          → `:connect_options[:transport_opts]`
    * `:hackney`      → translated for the well-known `:insecure` flag,
      every other key is silently dropped (and logged at `:debug`).

  Redirect following is disabled (`redirect: false`); `Funkspector.Resolver`
  is the sole authority for redirects.
  """

  @behaviour Funkspector.HTTP.Adapter

  require Logger

  alias Funkspector.{Response, Error}

  @impl true
  def get(url, opts) when is_map(opts) do
    req_opts = build_req_options(url, opts)

    try do
      case Req.request(req_opts) do
        {:ok, %Req.Response{status: status, headers: headers, body: body}} ->
          {:ok,
           %Response{
             status_code: status,
             headers: normalize_headers(headers),
             body: body_to_binary(body),
             request_url: url
           }}

        {:error, exception} ->
          {:error, %Error{reason: error_reason(exception), adapter: __MODULE__}}
      end
    rescue
      exception ->
        {:error, %Error{reason: error_reason(exception), adapter: __MODULE__}}
    end
  end

  ##############
  # Translation
  ##############

  defp build_req_options(url, opts) do
    base = [
      method: :get,
      url: url,
      redirect: false,
      decode_body: false,
      headers: request_headers(opts)
    ]

    base
    |> maybe_put(:auth, basic_auth(opts))
    |> maybe_put(:receive_timeout, opts[:recv_timeout])
    |> Keyword.merge(connect_options(opts))
  end

  defp request_headers(opts) do
    []
    |> maybe_prepend({"User-Agent", opts[:user_agent]})
  end

  defp maybe_prepend(list, {_k, nil}), do: list
  defp maybe_prepend(list, header), do: [header | list]

  defp maybe_put(kw, _key, nil), do: kw
  defp maybe_put(kw, key, value), do: Keyword.put(kw, key, value)

  defp basic_auth(%{basic_auth: {username, password}}),
    do: {:basic, "#{username}:#{password}"}

  defp basic_auth(_), do: nil

  defp connect_options(opts) do
    transport = transport_opts(opts)
    timeout = opts[:timeout]

    connect_opts =
      []
      |> maybe_put(:timeout, timeout)
      |> maybe_put(:transport_opts, transport)

    case connect_opts do
      [] -> []
      kw -> [connect_options: kw]
    end
  end

  defp transport_opts(opts) do
    from_ssl = opts[:ssl]
    from_hackney = hackney_transport_opts(opts[:hackney])

    case {from_ssl, from_hackney} do
      {nil, nil} -> nil
      {ssl, nil} -> ssl
      {nil, hackney} -> hackney
      {ssl, hackney} -> Keyword.merge(hackney, ssl)
    end
  end

  defp hackney_transport_opts(nil), do: nil

  defp hackney_transport_opts(list) when is_list(list) do
    {recognized, ignored} =
      Enum.split_with(list, fn
        :insecure -> true
        {:ssl_options, _} -> true
        _ -> false
      end)

    if ignored != [] do
      Logger.debug(fn ->
        "Funkspector Req adapter ignoring unrecognized :hackney options: #{inspect(ignored)}"
      end)
    end

    Enum.reduce(recognized, [], fn
      :insecure, acc -> Keyword.put(acc, :verify, :verify_none)
      {:ssl_options, ssl}, acc -> Keyword.merge(acc, ssl)
    end)
    |> case do
      [] -> nil
      kw -> kw
    end
  end

  defp hackney_transport_opts(_), do: nil

  ##############
  # Normalization
  ##############

  # Req returns headers as a map (`%{"content-type" => ["text/html"]}`); the
  # rest of Funkspector — the gzip-deflate logic in `Funkspector.Resolver`,
  # `Funkspector.Document` — expects a list of `{name, value}` tuples like
  # HTTPoison's. Flatten back to that shape.
  defp normalize_headers(headers) when is_map(headers) do
    for {name, values} <- headers, value <- List.wrap(values), do: {name, value}
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.map(headers, fn
      {name, value} when is_binary(value) -> {name, value}
      {name, [value | _]} -> {name, value}
      other -> other
    end)
  end

  defp normalize_headers(_), do: []

  defp body_to_binary(body) when is_binary(body), do: body
  defp body_to_binary(nil), do: ""
  defp body_to_binary(other), do: to_string(other)

  ##############
  # Error mapping
  ##############

  # Map Req/Mint exceptions onto the `gen_tcp`/`inet` atom contract that
  # `Funkspector.Resolver` and external callers expect.
  defp error_reason(%{reason: reason}) when not is_nil(reason), do: normalize_reason(reason)
  defp error_reason(exception), do: exception

  defp normalize_reason(:nxdomain), do: :nxdomain
  defp normalize_reason(:timeout), do: :timeout
  defp normalize_reason(:closed), do: :closed
  defp normalize_reason(:econnrefused), do: :econnrefused
  defp normalize_reason({:tls_alert, _} = reason), do: reason
  defp normalize_reason(reason), do: reason
end
