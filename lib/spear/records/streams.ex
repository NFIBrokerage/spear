defmodule Spear.Records.Streams do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Streams API
  """

  use Spear.Records, service_module: :streams
end
