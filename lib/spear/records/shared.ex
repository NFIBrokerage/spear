defmodule Spear.Records.Shared do
  require Spear.Records

  @moduledoc """
  Shared record definitions for EventStoreDB messages
  """

  Spear.Records.def_all_records(
    "event_store.client.shared.",
    "src/spear_proto_shared.hrl"
  )
end
