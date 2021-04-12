defmodule Spear.ExpectationViolation do
  @moduledoc """
  A structure representing how an append request's expectations were violated

  ## Expectations

  A client may exert expectations on write requests which will fail the request
  if violated. Any of these values may be passed to the `:expect` option of
  `Spear.append/4`:

  * `:any` - (default) any stream. Cannot be violated.
  * `:exists` - the EventStore stream must exist prior to the proposed events
    being written
  * `:empty` - the EventStore stream must **not** exist prior to the
    proposed events being written
  * `revision` - any positive integer representing the current size of the
    stream. The head of the EventStore stream must match this revision number
    in order for the append request to succeed.

  If an expectation is violated, the return signature will be
  `{:error, %Spear.ExpectationViolation{}}`, which gives information about
  the expectation and the current revision. See `t:t/0`.

  Expectations may also be set in `Spear.delete_stream/3`, although if
  expectations set on a deletion request are violated, EventStoreDB returns
  a gRPC error response instead of this struct.
  """

  defstruct [:current, :expected]

  @typedoc """
  A structure representing how an append request's expectations were violated

  This struct is returned on calls to `Spear.append/4` which set an expectation
  on the current stream revision with the `:expect` option.

  `:current` is not the number of events in the EventStore stream but rather
  the current event revision. If three events are appended to an empty stream,
  the `:current` will be `2`. Note that deletions do not reset a stream's
  revision number.

  ## Examples

      # say EventStore stream "stream_that_should_be_empty" has 6 events
      iex> Spear.append(events, conn, "stream_that_should_be_empty", expect: :empty)
      {:error, %Spear.ExpectationViolation{current: 5, expected: :empty}}

      # say EventStore stream "stream_that_should_have_events" has no events
      iex> Spear.append(events, conn, "stream_that_should_have_events", expect: :exists)
      {:error, %Spear.ExpectationViolation{current: :empty, expected: :exists}}
  """
  @typedoc since: "0.1.0"
  @type t :: %__MODULE__{
          current: pos_integer() | :empty,
          expected: pos_integer() | :empty | :exists | :any
        }
end
