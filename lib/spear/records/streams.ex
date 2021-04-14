defmodule Spear.Records.Streams do
  require Spear.Records

  Spear.Records.defrecords(
    "event_store.client.streams.",
    "src/spear_proto_streams.hrl"
  )
end
