defmodule Spear.ClusterMember do
  @moduledoc """
  A struct representing a member of a cluster of EventStoreDBs
  """
  @moduledoc since: "0.5.0"

  import Spear.Records.Gossip

  @typedoc """
  A struct representing a member of a cluster of EventStoreDBs

  These are returned by `Spear.cluster_info/2`.

  ## Examples

      iex> Spear.cluster_info(conn)
      {:ok,                 
       [
         %Spear.ClusterMember{
           address: "127.0.0.1",
           alive?: true,
           instance_id: "eba4c27f-e443-4b21-8756-00845bc5cda1",
           port: 2113,
           state: :Leader,
           timestamp: ~U[2021-04-19 17:25:17.875824Z]
         }
       ]}
  """
  @typedoc since: "0.5.0"
  @type t :: %__MODULE__{
          address: Mint.Types.address(),
          port: :inet.port_number(),
          timestamp: DateTime.t() | nil,
          instance_id: String.t(),
          state: state(),
          alive?: boolean()
        }

  @typedoc """
  A possible state for an EventStoreDB cluster member
  """
  @typedoc since: "0.5.0"
  @type state ::
          :Initializing
          | :DiscoverLeader
          | :Unknown
          | :PreReplica
          | :CatchingUp
          | :Clone
          | :Follower
          | :PreLeader
          | :Leader
          | :Manager
          | :ShuttingDown
          | :Shutdown
          | :ReadOnlyLeaderless
          | :PreReadOnlyReplica
          | :ResigningLeader

  defstruct ~w[address port timestamp instance_id state alive?]a

  def from_member_info(
        member_info(
          instance_id: instance_id,
          time_stamp: timestamp,
          state: state,
          is_alive: alive?,
          http_end_point: end_point(address: address, port: port)
        )
      ) do
    timestamp =
      case Spear.parse_stamp(timestamp) do
        {:ok, datetime} ->
          datetime

        # coveralls-ignore-start
        _ ->
          nil
          # coveralls-ignore-stop
      end

    %__MODULE__{
      instance_id: Spear.Uuid.from_proto(instance_id),
      timestamp: timestamp,
      state: state,
      alive?: alive?,
      address: address,
      port: port
    }
  end
end
