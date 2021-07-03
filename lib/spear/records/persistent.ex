defmodule Spear.Records.Persistent do
  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Persistent Subscriptions API
  """

  use Spear.Records, service_module: :persistent
end
