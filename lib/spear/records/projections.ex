defmodule Spear.Records.Projections do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Projections API
  """

  use Spear.Records, service_module: :spear_proto_projections
end
