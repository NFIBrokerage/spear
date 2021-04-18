defmodule Spear.Records.Operations do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Operations API
  """

  Spear.Records.from_hrl(:spear_proto_operations)
end
