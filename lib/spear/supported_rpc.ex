defmodule Spear.SupportedRpc do
  @moduledoc """
  A struct representing supported RPC in the currently connected
  EventStoreDB

  This structure is returned by `Spear.get_supported_rpcs/2`.
  """
  @moduledoc since: "0.11.0"

  require Spear.Records.ServerFeatures, as: ServerFeatures

  @typedoc """
  A struct representing a feature implemented by the currently connected
  EventStoreDB version

  See `Spear.get_supported_rpcs/2` for more information.
  """
  @typedoc since: "0.11.0"
  @type t :: %__MODULE__{rpc: String.t(), service: String.t(), features: [String.t()]}

  defstruct [:rpc, :service, features: []]

  @doc false
  def from_proto(
        ServerFeatures.supported_method(
          method_name: rpc,
          service_name: service_name,
          features: features
        )
      ) do
    %__MODULE__{rpc: rpc, service: service_name, features: features}
  end
end
