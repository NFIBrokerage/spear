defmodule Spear.Records.Streams do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Streams API
  """

  Spear.Records.def_all_records(
    "event_store.client.streams.",
    "src/spear_proto_streams.hrl"
  )
end
