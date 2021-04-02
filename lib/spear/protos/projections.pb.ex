defmodule EventStore.Client.Projections.CreateReq.Options.Transient do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }

  defstruct [:name]

  field :name, 1, type: :string
end

defmodule EventStore.Client.Projections.CreateReq.Options.Continuous do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          track_emitted_streams: boolean
        }

  defstruct [:name, :track_emitted_streams]

  field :name, 1, type: :string
  field :track_emitted_streams, 2, type: :bool
end

defmodule EventStore.Client.Projections.CreateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          mode: {atom, any},
          query: String.t()
        }

  defstruct [:mode, :query]

  oneof :mode, 0
  field :one_time, 1, type: EventStore.Client.Shared.Empty, oneof: 0
  field :transient, 2, type: EventStore.Client.Projections.CreateReq.Options.Transient, oneof: 0
  field :continuous, 3, type: EventStore.Client.Projections.CreateReq.Options.Continuous, oneof: 0
  field :query, 4, type: :string
end

defmodule EventStore.Client.Projections.CreateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.CreateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.CreateReq.Options
end

defmodule EventStore.Client.Projections.CreateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Projections.UpdateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          emit_option: {atom, any},
          name: String.t(),
          query: String.t()
        }

  defstruct [:emit_option, :name, :query]

  oneof :emit_option, 0
  field :name, 1, type: :string
  field :query, 2, type: :string
  field :emit_enabled, 3, type: :bool, oneof: 0
  field :no_emit_options, 4, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Projections.UpdateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.UpdateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.UpdateReq.Options
end

defmodule EventStore.Client.Projections.UpdateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Projections.DeleteReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          delete_emitted_streams: boolean,
          delete_state_stream: boolean,
          delete_checkpoint_stream: boolean
        }

  defstruct [:name, :delete_emitted_streams, :delete_state_stream, :delete_checkpoint_stream]

  field :name, 1, type: :string
  field :delete_emitted_streams, 2, type: :bool
  field :delete_state_stream, 3, type: :bool
  field :delete_checkpoint_stream, 4, type: :bool
end

defmodule EventStore.Client.Projections.DeleteReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.DeleteReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.DeleteReq.Options
end

defmodule EventStore.Client.Projections.DeleteResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Projections.StatisticsReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          mode: {atom, any}
        }

  defstruct [:mode]

  oneof :mode, 0
  field :name, 1, type: :string, oneof: 0
  field :all, 2, type: EventStore.Client.Shared.Empty, oneof: 0
  field :transient, 3, type: EventStore.Client.Shared.Empty, oneof: 0
  field :continuous, 4, type: EventStore.Client.Shared.Empty, oneof: 0
  field :one_time, 5, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Projections.StatisticsReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.StatisticsReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.StatisticsReq.Options
end

defmodule EventStore.Client.Projections.StatisticsResp.Details do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          coreProcessingTime: integer,
          version: integer,
          epoch: integer,
          effectiveName: String.t(),
          writesInProgress: integer,
          readsInProgress: integer,
          partitionsCached: integer,
          status: String.t(),
          stateReason: String.t(),
          name: String.t(),
          mode: String.t(),
          position: String.t(),
          progress: float | :infinity | :negative_infinity | :nan,
          lastCheckpoint: String.t(),
          eventsProcessedAfterRestart: integer,
          checkpointStatus: String.t(),
          bufferedEvents: integer,
          writePendingEventsBeforeCheckpoint: integer,
          writePendingEventsAfterCheckpoint: integer
        }

  defstruct [
    :coreProcessingTime,
    :version,
    :epoch,
    :effectiveName,
    :writesInProgress,
    :readsInProgress,
    :partitionsCached,
    :status,
    :stateReason,
    :name,
    :mode,
    :position,
    :progress,
    :lastCheckpoint,
    :eventsProcessedAfterRestart,
    :checkpointStatus,
    :bufferedEvents,
    :writePendingEventsBeforeCheckpoint,
    :writePendingEventsAfterCheckpoint
  ]

  field :coreProcessingTime, 1, type: :int64
  field :version, 2, type: :int64
  field :epoch, 3, type: :int64
  field :effectiveName, 4, type: :string
  field :writesInProgress, 5, type: :int32
  field :readsInProgress, 6, type: :int32
  field :partitionsCached, 7, type: :int32
  field :status, 8, type: :string
  field :stateReason, 9, type: :string
  field :name, 10, type: :string
  field :mode, 11, type: :string
  field :position, 12, type: :string
  field :progress, 13, type: :float
  field :lastCheckpoint, 14, type: :string
  field :eventsProcessedAfterRestart, 15, type: :int64
  field :checkpointStatus, 16, type: :string
  field :bufferedEvents, 17, type: :int64
  field :writePendingEventsBeforeCheckpoint, 18, type: :int32
  field :writePendingEventsAfterCheckpoint, 19, type: :int32
end

defmodule EventStore.Client.Projections.StatisticsResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          details: EventStore.Client.Projections.StatisticsResp.Details.t() | nil
        }

  defstruct [:details]

  field :details, 1, type: EventStore.Client.Projections.StatisticsResp.Details
end

defmodule EventStore.Client.Projections.StateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          partition: String.t()
        }

  defstruct [:name, :partition]

  field :name, 1, type: :string
  field :partition, 2, type: :string
end

defmodule EventStore.Client.Projections.StateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.StateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.StateReq.Options
end

defmodule EventStore.Client.Projections.StateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          state: Google.Protobuf.Value.t() | nil
        }

  defstruct [:state]

  field :state, 1, type: Google.Protobuf.Value
end

defmodule EventStore.Client.Projections.ResultReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          partition: String.t()
        }

  defstruct [:name, :partition]

  field :name, 1, type: :string
  field :partition, 2, type: :string
end

defmodule EventStore.Client.Projections.ResultReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.ResultReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.ResultReq.Options
end

defmodule EventStore.Client.Projections.ResultResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          result: Google.Protobuf.Value.t() | nil
        }

  defstruct [:result]

  field :result, 1, type: Google.Protobuf.Value
end

defmodule EventStore.Client.Projections.ResetReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          write_checkpoint: boolean
        }

  defstruct [:name, :write_checkpoint]

  field :name, 1, type: :string
  field :write_checkpoint, 2, type: :bool
end

defmodule EventStore.Client.Projections.ResetReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.ResetReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.ResetReq.Options
end

defmodule EventStore.Client.Projections.ResetResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Projections.EnableReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t()
        }

  defstruct [:name]

  field :name, 1, type: :string
end

defmodule EventStore.Client.Projections.EnableReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.EnableReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.EnableReq.Options
end

defmodule EventStore.Client.Projections.EnableResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Projections.DisableReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          name: String.t(),
          write_checkpoint: boolean
        }

  defstruct [:name, :write_checkpoint]

  field :name, 1, type: :string
  field :write_checkpoint, 2, type: :bool
end

defmodule EventStore.Client.Projections.DisableReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Projections.DisableReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Projections.DisableReq.Options
end

defmodule EventStore.Client.Projections.DisableResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Projections.Projections.Service do
  @moduledoc false
  use Spear.Service, name: "event_store.client.projections.Projections"

  rpc :Create, EventStore.Client.Projections.CreateReq, EventStore.Client.Projections.CreateResp

  rpc :Update, EventStore.Client.Projections.UpdateReq, EventStore.Client.Projections.UpdateResp

  rpc :Delete, EventStore.Client.Projections.DeleteReq, EventStore.Client.Projections.DeleteResp

  rpc :Statistics,
      EventStore.Client.Projections.StatisticsReq,
      stream(EventStore.Client.Projections.StatisticsResp)

  rpc :Disable,
      EventStore.Client.Projections.DisableReq,
      EventStore.Client.Projections.DisableResp

  rpc :Enable, EventStore.Client.Projections.EnableReq, EventStore.Client.Projections.EnableResp

  rpc :Reset, EventStore.Client.Projections.ResetReq, EventStore.Client.Projections.ResetResp

  rpc :State, EventStore.Client.Projections.StateReq, EventStore.Client.Projections.StateResp

  rpc :Result, EventStore.Client.Projections.ResultReq, EventStore.Client.Projections.ResultResp

  rpc :RestartSubsystem, EventStore.Client.Shared.Empty, EventStore.Client.Shared.Empty
end
