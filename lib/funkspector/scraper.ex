defmodule Funkspector.Scraper do
  alias Funkspector.Resolver

  def scrape(original_url) do
    case Resolver.resolve(original_url) do
      { :ok, final_url, response } ->
        handle_response(response, original_url, final_url)
      { _, url, response } ->
        { :error, url, response}
    end
  end

  def handle_response(response = %{status_code: status, body: _body }, original_url, _final_url) when not status in 200..299 do
    { :error, original_url, response }
  end

  def handle_response(%{status_code: status, body: body }, original_url, final_url) when status in 200..299 do
    { :ok, scraped_data(body, original_url, final_url) }
  end

  defp scraped_data(body, original_url, final_url) do
    %{
      body: body,
      original_url: original_url,
      final_url: final_url,
      root_url: root_url(final_url),
      links: %{
        raw: raw_links(body)
      }
    }
  end

  defp root_url(url) do
    %{scheme: scheme, host: host} = URI.parse(url)

    "#{scheme}://#{host}/"
  end

  defp raw_links(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
  end
end
