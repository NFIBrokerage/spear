# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
alias Spear.Protos.EventStore

defmodule EventStore.Client.Operations.ScavengeResp.ScavengeResult do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :Started | :InProgress | :Stopped

  field :Started, 0

  field :InProgress, 1

  field :Stopped, 2
end

defmodule EventStore.Client.Operations.StartScavengeReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          thread_count: integer,
          start_from_chunk: integer
        }

  defstruct [:thread_count, :start_from_chunk]

  field :thread_count, 1, type: :int32
  field :start_from_chunk, 2, type: :int32
end

defmodule EventStore.Client.Operations.StartScavengeReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Operations.StartScavengeReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Operations.StartScavengeReq.Options
end

defmodule EventStore.Client.Operations.StopScavengeReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          scavenge_id: String.t()
        }

  defstruct [:scavenge_id]

  field :scavenge_id, 1, type: :string
end

defmodule EventStore.Client.Operations.StopScavengeReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Operations.StopScavengeReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Operations.StopScavengeReq.Options
end

defmodule EventStore.Client.Operations.ScavengeResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          scavenge_id: String.t(),
          scavenge_result: EventStore.Client.Operations.ScavengeResp.ScavengeResult.t()
        }

  defstruct [:scavenge_id, :scavenge_result]

  field :scavenge_id, 1, type: :string

  field :scavenge_result, 2,
    type: EventStore.Client.Operations.ScavengeResp.ScavengeResult,
    enum: true
end

defmodule EventStore.Client.Operations.SetNodePriorityReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          priority: integer
        }

  defstruct [:priority]

  field :priority, 1, type: :int32
end

defmodule EventStore.Client.Operations.Operations.Service do
  @moduledoc false
  use Spear.Service, name: "event_store.client.operations.Operations"

  rpc :StartScavenge,
      EventStore.Client.Operations.StartScavengeReq,
      EventStore.Client.Operations.ScavengeResp

  rpc :StopScavenge,
      EventStore.Client.Operations.StopScavengeReq,
      EventStore.Client.Operations.ScavengeResp

  rpc :Shutdown, EventStore.Client.Shared.Empty, EventStore.Client.Shared.Empty

  rpc :MergeIndexes, EventStore.Client.Shared.Empty, EventStore.Client.Shared.Empty

  rpc :ResignNode, EventStore.Client.Shared.Empty, EventStore.Client.Shared.Empty

  rpc :SetNodePriority,
      EventStore.Client.Operations.SetNodePriorityReq,
      EventStore.Client.Shared.Empty

  rpc :RestartPersistentSubscriptions,
      EventStore.Client.Shared.Empty,
      EventStore.Client.Shared.Empty
end
