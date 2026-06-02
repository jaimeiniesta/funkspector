defmodule Funkspector.Response do
  @moduledoc """
  Normalized HTTP response, adapter-agnostic.

  Every Funkspector HTTP adapter (see `Funkspector.HTTP.Adapter`) returns
  responses in this shape, so the rest of the pipeline (`Funkspector.Resolver`,
  `Funkspector.Document`, the scrapers) never sees adapter-specific structs.
  """

  @type header :: {String.t(), String.t()}

  @type t :: %__MODULE__{
          status_code: non_neg_integer() | nil,
          headers: [header()],
          body: binary() | nil,
          request_url: String.t() | nil
        }

  @enforce_keys [:status_code, :headers, :body]
  defstruct status_code: nil, headers: [], body: nil, request_url: nil
end
