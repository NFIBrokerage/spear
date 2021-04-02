defmodule EventStore.Client.Gossip.MemberInfo.VNodeState do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3

  @type t ::
          integer
          | :Initializing
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
          | :ReadOnlyReplica
          | :ResigningLeader

  field :Initializing, 0

  field :DiscoverLeader, 1

  field :Unknown, 2

  field :PreReplica, 3

  field :CatchingUp, 4

  field :Clone, 5

  field :Follower, 6

  field :PreLeader, 7

  field :Leader, 8

  field :Manager, 9

  field :ShuttingDown, 10

  field :Shutdown, 11

  field :ReadOnlyLeaderless, 12

  field :PreReadOnlyReplica, 13

  field :ReadOnlyReplica, 14

  field :ResigningLeader, 15
end

defmodule EventStore.Client.Gossip.ClusterInfo do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          members: [EventStore.Client.Gossip.MemberInfo.t()]
        }

  defstruct [:members]

  field :members, 1, repeated: true, type: EventStore.Client.Gossip.MemberInfo
end

defmodule EventStore.Client.Gossip.EndPoint do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          address: String.t(),
          port: non_neg_integer
        }

  defstruct [:address, :port]

  field :address, 1, type: :string
  field :port, 2, type: :uint32
end

defmodule EventStore.Client.Gossip.MemberInfo do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          instance_id: EventStore.Client.Shared.UUID.t() | nil,
          time_stamp: integer,
          state: EventStore.Client.Gossip.MemberInfo.VNodeState.t(),
          is_alive: boolean,
          http_end_point: EventStore.Client.Gossip.EndPoint.t() | nil
        }

  defstruct [:instance_id, :time_stamp, :state, :is_alive, :http_end_point]

  field :instance_id, 1, type: EventStore.Client.Shared.UUID
  field :time_stamp, 2, type: :int64
  field :state, 3, type: EventStore.Client.Gossip.MemberInfo.VNodeState, enum: true
  field :is_alive, 4, type: :bool
  field :http_end_point, 5, type: EventStore.Client.Gossip.EndPoint
end

defmodule EventStore.Client.Gossip.Gossip.Service do
  @moduledoc false
  use Spear.Service, name: "event_store.client.gossip.Gossip"

  rpc :Read, EventStore.Client.Shared.Empty, EventStore.Client.Gossip.ClusterInfo
end
