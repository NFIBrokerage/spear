defmodule Spear.Records.Shared do
  require Spear.Records

  @moduledoc """
  Shared record definitions for EventStoreDB messages
  """

  Spear.Records.from_hrl(:spear_proto_shared)
end
