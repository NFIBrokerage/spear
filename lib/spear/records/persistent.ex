defmodule Spear.Records.Persistent do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Persistent Subscriptions API
  """

  Spear.Records.from_hrl(:spear_proto_persistent)
end
