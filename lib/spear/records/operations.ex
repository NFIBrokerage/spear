defmodule Spear.Records.Operations do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Operations API
  """

  use Spear.Records, service_module: :spear_proto_operations
end
