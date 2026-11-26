defmodule Funkspector.HTTP.Adapters.Req do
  @moduledoc """
  Default Funkspector HTTP adapter, backed by [Req](https://hex.pm/packages/req)
  (Finch/Mint).

  Req does not depend on hackney, so this adapter is the recommended path for
  new code: it is unaffected by the hackney 1.x security issues the legacy
  `HTTPoison`/`hackney 1.21` stack carries — notably
  [CVE-2026-47075](https://nvd.nist.gov/vuln/detail/CVE-2026-47075) (CRLF
  injection / request splitting) and
  [CVE-2026-47076](https://nvd.nist.gov/vuln/detail/CVE-2026-47076) (SSRF via
  URL normalization). Both are fixed in hackney 4.0.1, which HTTPoison's
  `~> 1.21` constraint cannot reach
  ([httpoison#501](https://github.com/edgurgel/httpoison/issues/501)).

  Funkspector options are translated to Req options at the boundary:

    * `:user_agent`   → `User-Agent` header
    * `:basic_auth`   → `:auth` (basic)
    * `:timeout`      → `:connect_options[:timeout]` (TCP/TLS connect only)
    * `:recv_timeout` → `:receive_timeout` (per *chunk*, not a total-time bound)
    * `:insecure`     → `verify: :verify_none` in the TLS transport opts.
      Off by default, so certificates are verified (`verify: :verify_peer`).
    * `:ssl`          → `:connect_options[:transport_opts]` (wins over `:insecure`)
    * `:hackney`      → translated for the well-known `:insecure` flag,
      every other key is silently dropped (and logged at `:debug`).
    * `:max_body_size` → responses whose body exceeds this many bytes are
      rejected with `%Funkspector.Error{reason: :body_too_large}`. The body is
      read chunk by chunk and the download stops as soon as it passes the
      limit. `:infinity` (or absence) disables the check.

  Redirect following is disabled (`redirect: false`); `Funkspector.Resolver`
  is the sole authority for redirects.
  """

  @behaviour Funkspector.HTTP.Adapter

  require Logger

  alias Funkspector.{Response, Error}

  @impl true
  def get(url, %{body: mode} = opts) when mode in [:headers, :stream] do
    req_opts =
      url
      |> build_req_options(Map.delete(opts, :max_body_size))
      |> Keyword.merge(into: :self, compressed: false)
      |> Keyword.update!(:headers, &[{"accept-encoding", "identity"} | &1])

    try do
      case Req.request(req_opts) do
        {:ok, %Req.Response{status: status, headers: headers} = response} ->
          {:ok,
           %Response{
             status_code: status,
             headers: normalize_headers(headers),
             body: async_body(response, mode),
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

  def get(url, opts) when is_map(opts) do
    req_opts = build_req_options(url, opts)

    try do
      case Req.request(req_opts) do
        {:ok, %Req.Response{private: %{funkspector_too_large: true}}} ->
          {:error, %Error{reason: :body_too_large, adapter: __MODULE__}}

        {:ok, %Req.Response{status: status, headers: headers} = response} ->
          build_response(url, status, headers, received_body(response), opts[:max_body_size])

        {:error, exception} ->
          {:error, %Error{reason: error_reason(exception), adapter: __MODULE__}}
      end
    rescue
      exception ->
        {:error, %Error{reason: error_reason(exception), adapter: __MODULE__}}
    end
  end

  # In headers mode the body is never read: the connection is cancelled as
  # soon as the headers are in. In stream mode the caller reads it.
  defp async_body(response, :headers) do
    Req.cancel_async_response(response)
    nil
  end

  defp async_body(%Req.Response{body: body}, :stream), do: body

  defp build_response(url, status, headers, body, max_body_size) do
    if within_limit?(body, max_body_size) do
      {:ok,
       %Response{
         status_code: status,
         headers: normalize_headers(headers),
         body: body,
         request_url: url
       }}
    else
      {:error, %Error{reason: :body_too_large, adapter: __MODULE__}}
    end
  end

  defp within_limit?(_body, nil), do: true
  defp within_limit?(_body, :infinity), do: true
  defp within_limit?(body, limit) when is_integer(limit), do: byte_size(body) <= limit

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
    |> put_body_limit(opts[:max_body_size])
    |> Keyword.merge(connect_options(opts))
  end

  # Req only asks for a compressed body when it reads the body itself, so with
  # the chunk-by-chunk limit we ask for gzip ourselves. `Funkspector.Resolver`
  # inflates it, within the same limit.
  defp put_body_limit(req_opts, limit) do
    case body_limit(limit) do
      nil ->
        req_opts

      into ->
        req_opts
        |> Keyword.put(:into, into)
        |> Keyword.update!(:headers, &[{"accept-encoding", "gzip"} | &1])
    end
  end

  # With an integer limit the body is collected chunk by chunk and the
  # download stops as soon as it passes the limit, so a huge or endless body
  # never has to be received in full. Chunks are kept as iodata in the
  # response's private map and joined once at the end.
  defp body_limit(limit) when is_integer(limit) do
    fn {:data, data}, {request, response} ->
      size = Req.Response.get_private(response, :funkspector_size, 0) + byte_size(data)
      chunks = [Req.Response.get_private(response, :funkspector_chunks, []) | data]

      response =
        response
        |> Req.Response.put_private(:funkspector_size, size)
        |> Req.Response.put_private(:funkspector_chunks, chunks)

      if size > limit do
        {:halt, {request, Req.Response.put_private(response, :funkspector_too_large, true)}}
      else
        {:cont, {request, response}}
      end
    end
  end

  defp body_limit(_limit), do: nil

  defp received_body(%Req.Response{private: %{funkspector_chunks: chunks}}),
    do: IO.iodata_to_binary(chunks)

  defp received_body(%Req.Response{body: body}), do: body_to_binary(body)

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

  # Builds the `:transport_opts` for the TLS connection by layering, in
  # increasing precedence: the `:insecure` flag, the legacy `:hackney`
  # `:insecure`/`:ssl_options`, and finally an explicit `:ssl` keyword list.
  # An explicit `:ssl` therefore always wins, and any of the three can turn
  # verification off. When none are given the result is `nil`, so Req/Mint
  # keeps its secure `verify: :verify_peer` default.
  defp transport_opts(opts) do
    [
      insecure_transport_opts(opts[:insecure]),
      hackney_transport_opts(opts[:hackney]),
      opts[:ssl]
    ]
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      layers -> Enum.reduce(layers, [], &Keyword.merge(&2, &1))
    end
  end

  defp insecure_transport_opts(true), do: [verify: :verify_none]
  defp insecure_transport_opts(_), do: nil

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
  # `Funkspector.Resolver` and external callers expect. Exceptions without a
  # transport `:reason` (e.g. a generic runtime error inside Req) are collapsed
  # to a stable `{:adapter_error, message}` tuple rather than leaking the raw
  # library struct past the normalized contract.
  defp error_reason(%{reason: reason}) when not is_nil(reason), do: normalize_reason(reason)

  defp error_reason(exception) when is_exception(exception),
    do: {:adapter_error, Exception.message(exception)}

  defp error_reason(other), do: other

  defp normalize_reason(:nxdomain), do: :nxdomain
  defp normalize_reason(:timeout), do: :timeout
  defp normalize_reason(:closed), do: :closed
  defp normalize_reason(:econnrefused), do: :econnrefused
  defp normalize_reason({:tls_alert, _} = reason), do: reason
  defp normalize_reason(reason), do: reason
end
