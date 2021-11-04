defmodule Spear.Records.ServerFeatures do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB
  ServerFeatures API introduced in server version v21.10.0
  """

  use Spear.Records, service_module: :serverfeatures
end
