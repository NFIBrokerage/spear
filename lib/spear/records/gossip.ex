defmodule Spear.Records.Gossip do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Gossip API
  """

  use Spear.Records, service_module: :gossip
end
