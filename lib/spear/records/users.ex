defmodule Spear.Records.Users do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Users API
  """

  use Spear.Records, service_module: :users
end
