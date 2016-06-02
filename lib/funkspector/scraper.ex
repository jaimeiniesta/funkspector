defmodule Funkspector.Scraper do
  def scrape(url) do
    url
    |> HTTPoison.get
    |> handle_response
  end

  def handle_response({ :ok, %{status_code: status, body: body }}) when status in 200..299 do
    { :ok, scraped_data(body) }
  end

  def handle_response({ _,   %{status_code: _,   body: body}}) do
    { :error, body }
  end

  defp scraped_data(body) do
    %{
      body: body
    }
  end
end
