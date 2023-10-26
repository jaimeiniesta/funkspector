defmodule Funkspector.Utils do
  @moduledoc """
  Common functionality for the scrapers.
  """

  @url_regexp Application.compile_env(:funkspector, :url_regexp)

  @doc """
  Given a collection of URLs and a base URL, absolutifies the relative links.

  ## Examples

      iex> Funkspector.Utils.absolutify(["javascript:alert(hi)", "/faqs?section=legal", "/about", "http://example.com/faqs"], "http://example.com")
      ["javascript:alert(hi)", "http://example.com/faqs?section=legal", "http://example.com/about", "http://example.com/faqs"]
  """
  def absolutify(links, base_url) when is_list(links) do
    links
    |> Enum.map(&absolutify(&1, base_url))
  end

  def absolutify(link, base_url) when is_binary(link) do
    URI.merge(base_url, link) |> to_string()
  end

  @doc """
  Returns a boolean telling if the URL seems valid according to the regexp.

  ## Examples

  iex> Funkspector.Utils.valid_url?("https://example.com")
  true

  iex> Funkspector.Utils.valid_url?("joe@example.com")
  false

  iex> Funkspector.Utils.valid_url?(nil)
  false

  iex> Funkspector.Utils.valid_url?("  ")
  false
  """
  def valid_url?(url) when is_binary(url) do
    Regex.match?(@url_regexp, url)
  end

  def valid_url?(_), do: false
end
