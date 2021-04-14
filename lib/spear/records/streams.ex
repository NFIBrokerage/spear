defmodule Spear.Records.Streams do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Streams API

  Macros in this module are generated with `Record.defrecord/2` with the
  contents extracted from the protobuf messages (indirectly via `:gpb`).
  These macros may be used to match on messages received from the EventStoreDB
  and to produce messages one wishes to send to the EventStoreDB.

  ## Examples

      iex> event = Spear.stream!(conn, "my_stream") |> Enum.take(1) |> List.first()
      {:"event_store.client.streams.ReadResp", ..}
      iex> import Spear.Records.Streams, only: [read_resp: 0]
      iex> match?(read_resp(), event)
      true
  """

  Spear.Records.def_all_records(
    "event_store.client.streams.",
    "src/spear_proto_streams.hrl"
  )
end
