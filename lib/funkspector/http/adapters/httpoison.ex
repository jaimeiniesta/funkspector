defmodule Funkspector.HTTP.Adapters.HTTPoison do
  @moduledoc """
  Opt-in Funkspector HTTP adapter, backed by
  [HTTPoison](https://hex.pm/packages/httpoison) on top of hackney.

  This is the historical Funkspector HTTP path, preserved for users who
  cannot — or do not want to — move to Req yet. The defaults here match
  the pre-2.0 behavior:

    * `hackney: [:insecure]` (cert chain verification disabled);
    * `:user_agent`, `:basic_auth`, `:ssl`, `:timeout`, `:recv_timeout`
      pass straight through to HTTPoison/hackney.

  Errors from HTTPoison/hackney are translated to `%Funkspector.Error{}`
  so the rest of the pipeline does not see adapter-specific structs.

  Activate via application config or per-call options:

      config :funkspector, :http_adapter, Funkspector.HTTP.Adapters.HTTPoison

      Funkspector.resolve(url, %{adapter: Funkspector.HTTP.Adapters.HTTPoison})

  > #### Security note {: .warning}
  > hackney 1.21 is still vulnerable to the
  > CVE-2026-47066..47076 cluster (Alt-Svc parsing, WebSocket framing,
  > SSRF via redirects, CR/LF injection). Prefer the Req adapter for new
  > integrations.
  """

  @behaviour Funkspector.HTTP.Adapter

  alias Funkspector.{Response, Error}

  @impl true
  def get(url, opts) when is_map(opts) do
    {headers, request_options} = request_headers_and_options(opts)

    case HTTPoison.get(url, headers, Map.to_list(request_options)) do
      {:ok, %HTTPoison.Response{status_code: status, headers: response_headers, body: body}} ->
        {:ok,
         %Response{
           status_code: status,
           headers: response_headers,
           body: body,
           request_url: url
         }}

      {:ok, %{status_code: status, headers: response_headers, body: body}} ->
        {:ok,
         %Response{
           status_code: status,
           headers: response_headers,
           body: body,
           request_url: url
         }}

      {:ok, %{status_code: status, headers: response_headers}} ->
        {:ok,
         %Response{
           status_code: status,
           headers: response_headers,
           body: nil,
           request_url: url
         }}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, %Error{reason: reason, adapter: __MODULE__}}

      {:error, %{reason: reason}} ->
        {:error, %Error{reason: reason, adapter: __MODULE__}}

      {:error, reason} ->
        {:error, %Error{reason: reason, adapter: __MODULE__}}
    end
  end

  defp request_headers_and_options(options) do
    headers = request_headers(options)

    options =
      options
      |> Map.delete(:user_agent)
      |> Map.delete(:basic_auth)
      |> Map.delete(:adapter)
      |> Map.delete(:contents)
      |> Map.delete(:connect_options)

    {headers, options}
  end

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
