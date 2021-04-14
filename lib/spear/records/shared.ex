defmodule Spear.Records.Shared do
  require Spear.Records

  Spear.Records.defrecords(
    "event_store.client.shared.",
    "src/spear_proto_shared.hrl"
  )
end
