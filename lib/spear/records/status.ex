defmodule Spear.Records.Status do
  @moduledoc """
  A record macro interface for interacting with the google.rpc.Status type
  used in the protos
  """

  use Spear.Records, service_module: :status
end
