defmodule Funkspector.SitemapScraper do
  @moduledoc """
  Provides a method to scrape an XML sitemap, given its URL.
  """

  import Funkspector.Utils
  alias Funkspector.Resolver

  @doc """
  Fetches the given URL, follows redirections, and returns the data scraped from its XML.
  """
  def scrape(original_url) do
    case Resolver.resolve(original_url) do
      { :ok, final_url, response } ->
        handle_response(response, original_url, final_url)
      { _, url, response } ->
        { :error, url, response}
    end
  end

  defp handle_response(response = %{status_code: status, body: _body }, original_url, _final_url) when not status in 200..299 do
    { :error, original_url, response }
  end

  defp handle_response(%{status_code: status, body: body }, original_url, final_url) when status in 200..299 do
    try do
      { :ok, scraped_data(body, original_url, final_url) }
    catch
      :exit, reason -> { :error, original_url, %{ malformed_xml: reason } }
    end
  end

  defp scraped_data(body, original_url, final_url) do
    %{scheme: scheme, host: host} = URI.parse(final_url)

    root_url = "#{scheme}://#{host}/"
    locs     = raw_locs(body) |> absolutify(root_url)

    %{
      scheme: scheme,
      host: host,
      original_url: original_url,
      final_url: final_url,
      root_url: root_url,
      body: body,
      locs: locs
    }
  end

  defp raw_locs(xml) do
    xml
    |> Quinn.parse
    |> Quinn.find(:loc)
    |> Enum.map(&(&1[:value]))
    |> List.flatten
    |> Enum.uniq
  end
end
