defmodule Spear.StreamPosition do
  @moduledoc """
  A data structure representing a position in a stream

  EventStoreDB emits this data while reading a stream (with `Spear.stream!/3`
  or `Spear.subscribe/4`) since version [TODO].
  """

  # TODO
  # revisit this branch when the next release of EventStoreDB comes out
  # and fill in the above version, as well as adding documentation and
  # doc metadata for this module
  # also document Spear.AllPosition

  require Spear.Records.Streams, as: Streams
  alias Spear.AllPosition

  @type t :: %__MODULE__{
          kind: :revision | :all_position,
          next: integer() | Spear.AllPosition.t(),
          last: integer() | Spear.AllPosition.t()
        }

  defstruct [:kind, :next, :last]

  def from_read_response(
        Streams.read_resp(
          content:
            {:stream_position,
             Streams.read_resp_stream_position(
               next_stream_position: next,
               last_stream_position: last
             )}
        )
      ) do
    %__MODULE__{kind: :revision, next: next, last: last}
  end

  def from_read_response(
        Streams.read_resp(
          content:
            {:all_stream_position,
             Streams.read_resp_all_stream_position(next_position: next, last_position: last)}
        )
      ) do
    %__MODULE__{
      kind: :all_position,
      next: AllPosition.from_record(next),
      last: AllPosition.from_record(last)
    }
  end
end
