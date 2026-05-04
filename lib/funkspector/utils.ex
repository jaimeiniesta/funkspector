defmodule Funkspector.Utils do
  @moduledoc """
  Common utility functions shared across the scrapers.

  Provides URL absolutification (converting relative URLs to absolute)
  and URL validation using a regular expression that supports internationalized domain names.
  """

  @url_regexp ~r/\Ahttp(s?)\:\/\/[a-zñäëïöüáéíóúàèìòùâêîôû0-9\-_]+([\.]{1}[a-zñäëïöüáéíóúàèìòùâêîôû0-9\-]+)*\.[a-z0-9]{2,5}(([0-9]{1,5})?(:(\d{1,5}))?([\/\?#].*)?)?\z/i

  @doc """
  Converts relative URLs to absolute URLs using the given base URL.

  Accepts either a single URL string or a list of URL strings. Non-HTTP URLs
  (like `javascript:` or `mailto:`) are passed through `URI.merge/2` unchanged
  in practice, though the result depends on the URI scheme.

  ## Examples

      iex> Funkspector.Utils.absolutify(["javascript:alert(hi)", "/faqs?section=legal", "/about", "http://example.com/faqs"], "http://example.com")
      ["javascript:alert(hi)", "http://example.com/faqs?section=legal", "http://example.com/about", "http://example.com/faqs"]
  """
  @spec absolutify([String.t()], String.t()) :: [String.t()]
  def absolutify(links, base_url) when is_list(links) do
    links
    |> Enum.map(&absolutify(&1, base_url))
  end

  @spec absolutify(String.t(), String.t()) :: String.t()
  def absolutify(link, base_url) when is_binary(link) do
    URI.merge(base_url, link) |> to_string()
  end

  @doc """
  Returns whether the given URL matches a valid HTTP/HTTPS URL pattern.

  Uses a regular expression that supports internationalized domain names
  (with characters like ñ, ä, ë, etc.). Returns `false` for non-binary values.

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
  @spec valid_url?(any()) :: boolean()
  def valid_url?(url) when is_binary(url) do
    Regex.match?(@url_regexp, url)
  end

  def valid_url?(_), do: false
end
