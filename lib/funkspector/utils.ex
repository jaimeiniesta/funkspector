defmodule Funkspector.Utils do
  @moduledoc """
  Common functionality for the scrapers.
  """

  @doc """
  Given a collection of URLs and a base URL, absolutifies the relative links.

  ## Examples

      iex> Funkspector.Utils.absolutify ["/faqs?section=legal", "/about"], "http://example.com"
      ["http://example.com/faqs?section=legal", "http://example.com/about"]
  """
  def absolutify(links, root_url) do
    links
    |> Enum.map(&(URI.merge(root_url, &1) |> to_string))
  end
end
