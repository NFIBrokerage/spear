defmodule Spear.Records.Streams do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Streams API
  """

  Spear.Records.from_hrl(:spear_proto_streams)
end
