defmodule Funkspector.Error do
  @moduledoc """
  Normalized HTTP error, adapter-agnostic.

  `:reason` is an atom (or tagged tuple) drawn from `gen_tcp`/`inet`'s
  vocabulary — for example `:nxdomain`, `:timeout`, `:closed`,
  `{:tls_alert, _}`. Each adapter is responsible for translating its
  native error type onto this contract; downstream code (the SSL retry
  logic in `Funkspector.Resolver`, callers' own pattern matches) can
  then ignore which HTTP library produced the failure.

  `:adapter` records which adapter module produced the error, useful for
  debugging and for callers that want to surface different messages per
  backend.
  """

  @type t :: %__MODULE__{
          reason: atom() | tuple(),
          adapter: module() | nil
        }

  @enforce_keys [:reason]
  defstruct reason: nil, adapter: nil
end
