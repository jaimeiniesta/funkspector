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
    %{scheme: scheme, host: host} = URI.parse(final_url)

    raw_links                          = raw_links(body)
    { http_links, non_http_links }     = http_and_non_http(raw_links)
    { internal_links, external_links } = internal_and_external(http_links, host)

    %{
      scheme: scheme,
      host: host,
      original_url: original_url,
      final_url: final_url,
      root_url: "#{scheme}://#{host}/",
      body: body,
      links: %{
        raw: raw_links,
        http: %{
          internal: internal_links,
          external: external_links
        },
        non_http: non_http_links
      }
    }
  end

  defp raw_links(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
  end

  defp http_and_non_http(links) do
    Enum.partition(links, &(&1 =~ ~r/^http(s)?:\/\//i))
  end

  defp internal_and_external(links, host) do
    Enum.partition(links, &(&1 =~ ~r/^http(s)?:\/\/#{host}/i))
  end
end
