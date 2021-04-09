# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
alias Spear.Protos.EventStore

defmodule EventStore.Client.PersistentSubscriptions.ReadReq.Nack.Action do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :Unknown | :Park | :Retry | :Skip | :Stop

  field :Unknown, 0

  field :Park, 1

  field :Retry, 2

  field :Skip, 3

  field :Stop, 4
end

defmodule EventStore.Client.PersistentSubscriptions.CreateReq.ConsumerStrategy do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :DispatchToSingle | :RoundRobin | :Pinned

  field :DispatchToSingle, 0

  field :RoundRobin, 1

  field :Pinned, 2
end

defmodule EventStore.Client.PersistentSubscriptions.UpdateReq.ConsumerStrategy do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :DispatchToSingle | :RoundRobin | :Pinned

  field :DispatchToSingle, 0

  field :RoundRobin, 1

  field :Pinned, 2
end

defmodule EventStore.Client.PersistentSubscriptions.ReadReq.Options.UUIDOption do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: {atom, any}
        }

  defstruct [:content]

  oneof :content, 0
  field :structured, 1, type: EventStore.Client.Shared.Empty, oneof: 0
  field :string, 2, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.PersistentSubscriptions.ReadReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil,
          group_name: String.t(),
          buffer_size: integer,
          uuid_option:
            EventStore.Client.PersistentSubscriptions.ReadReq.Options.UUIDOption.t() | nil
        }

  defstruct [:stream_identifier, :group_name, :buffer_size, :uuid_option]

  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :group_name, 2, type: :string
  field :buffer_size, 3, type: :int32

  field :uuid_option, 4,
    type: EventStore.Client.PersistentSubscriptions.ReadReq.Options.UUIDOption
end

defmodule EventStore.Client.PersistentSubscriptions.ReadReq.Ack do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: binary,
          ids: [EventStore.Client.Shared.UUID.t()]
        }

  defstruct [:id, :ids]

  field :id, 1, type: :bytes
  field :ids, 2, repeated: true, type: EventStore.Client.Shared.UUID
end

defmodule EventStore.Client.PersistentSubscriptions.ReadReq.Nack do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: binary,
          ids: [EventStore.Client.Shared.UUID.t()],
          action: EventStore.Client.PersistentSubscriptions.ReadReq.Nack.Action.t(),
          reason: String.t()
        }

  defstruct [:id, :ids, :action, :reason]

  field :id, 1, type: :bytes
  field :ids, 2, repeated: true, type: EventStore.Client.Shared.UUID

  field :action, 3,
    type: EventStore.Client.PersistentSubscriptions.ReadReq.Nack.Action,
    enum: true

  field :reason, 4, type: :string
end

defmodule EventStore.Client.PersistentSubscriptions.ReadReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: {atom, any}
        }

  defstruct [:content]

  oneof :content, 0
  field :options, 1, type: EventStore.Client.PersistentSubscriptions.ReadReq.Options, oneof: 0
  field :ack, 2, type: EventStore.Client.PersistentSubscriptions.ReadReq.Ack, oneof: 0
  field :nack, 3, type: EventStore.Client.PersistentSubscriptions.ReadReq.Nack, oneof: 0
end

defmodule EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent.MetadataEntry do
  @moduledoc false
  use Protobuf, map: true, syntax: :proto3

  @type t :: %__MODULE__{
          key: String.t(),
          value: String.t()
        }

  defstruct [:key, :value]

  field :key, 1, type: :string
  field :value, 2, type: :string
end

defmodule EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: EventStore.Client.Shared.UUID.t() | nil,
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil,
          stream_revision: non_neg_integer,
          prepare_position: non_neg_integer,
          commit_position: non_neg_integer,
          metadata: %{String.t() => String.t()},
          custom_metadata: binary,
          data: binary
        }

  defstruct [
    :id,
    :stream_identifier,
    :stream_revision,
    :prepare_position,
    :commit_position,
    :metadata,
    :custom_metadata,
    :data
  ]

  field :id, 1, type: EventStore.Client.Shared.UUID
  field :stream_identifier, 2, type: EventStore.Client.Shared.StreamIdentifier
  field :stream_revision, 3, type: :uint64
  field :prepare_position, 4, type: :uint64
  field :commit_position, 5, type: :uint64

  field :metadata, 6,
    repeated: true,
    type:
      EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent.MetadataEntry,
    map: true

  field :custom_metadata, 7, type: :bytes
  field :data, 8, type: :bytes
end

defmodule EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          position: {atom, any},
          count: {atom, any},
          event:
            EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent.t() | nil,
          link:
            EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent.t() | nil
        }

  defstruct [:position, :count, :event, :link]

  oneof :position, 0
  oneof :count, 1

  field :event, 1,
    type: EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent

  field :link, 2, type: EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent.RecordedEvent
  field :commit_position, 3, type: :uint64, oneof: 0
  field :no_position, 4, type: EventStore.Client.Shared.Empty, oneof: 0
  field :retry_count, 5, type: :int32, oneof: 1
  field :no_retry_count, 6, type: EventStore.Client.Shared.Empty, oneof: 1
end

defmodule EventStore.Client.PersistentSubscriptions.ReadResp.SubscriptionConfirmation do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subscription_id: String.t()
        }

  defstruct [:subscription_id]

  field :subscription_id, 1, type: :string
end

defmodule EventStore.Client.PersistentSubscriptions.ReadResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: {atom, any}
        }

  defstruct [:content]

  oneof :content, 0
  field :event, 1, type: EventStore.Client.PersistentSubscriptions.ReadResp.ReadEvent, oneof: 0

  field :subscription_confirmation, 2,
    type: EventStore.Client.PersistentSubscriptions.ReadResp.SubscriptionConfirmation,
    oneof: 0
end

defmodule EventStore.Client.PersistentSubscriptions.CreateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil,
          group_name: String.t(),
          settings: EventStore.Client.PersistentSubscriptions.CreateReq.Settings.t() | nil
        }

  defstruct [:stream_identifier, :group_name, :settings]

  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :group_name, 2, type: :string
  field :settings, 3, type: EventStore.Client.PersistentSubscriptions.CreateReq.Settings
end

defmodule EventStore.Client.PersistentSubscriptions.CreateReq.Settings do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          message_timeout: {atom, any},
          checkpoint_after: {atom, any},
          resolve_links: boolean,
          revision: non_neg_integer,
          extra_statistics: boolean,
          max_retry_count: integer,
          min_checkpoint_count: integer,
          max_checkpoint_count: integer,
          max_subscriber_count: integer,
          live_buffer_size: integer,
          read_batch_size: integer,
          history_buffer_size: integer,
          named_consumer_strategy:
            EventStore.Client.PersistentSubscriptions.CreateReq.ConsumerStrategy.t()
        }

  defstruct [
    :message_timeout,
    :checkpoint_after,
    :resolve_links,
    :revision,
    :extra_statistics,
    :max_retry_count,
    :min_checkpoint_count,
    :max_checkpoint_count,
    :max_subscriber_count,
    :live_buffer_size,
    :read_batch_size,
    :history_buffer_size,
    :named_consumer_strategy
  ]

  oneof :message_timeout, 0
  oneof :checkpoint_after, 1
  field :resolve_links, 1, type: :bool
  field :revision, 2, type: :uint64
  field :extra_statistics, 3, type: :bool
  field :max_retry_count, 5, type: :int32
  field :min_checkpoint_count, 7, type: :int32
  field :max_checkpoint_count, 8, type: :int32
  field :max_subscriber_count, 9, type: :int32
  field :live_buffer_size, 10, type: :int32
  field :read_batch_size, 11, type: :int32
  field :history_buffer_size, 12, type: :int32

  field :named_consumer_strategy, 13,
    type: EventStore.Client.PersistentSubscriptions.CreateReq.ConsumerStrategy,
    enum: true

  field :message_timeout_ticks, 4, type: :int64, oneof: 0
  field :message_timeout_ms, 14, type: :int32, oneof: 0
  field :checkpoint_after_ticks, 6, type: :int64, oneof: 1
  field :checkpoint_after_ms, 15, type: :int32, oneof: 1
end

defmodule EventStore.Client.PersistentSubscriptions.CreateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.PersistentSubscriptions.CreateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.PersistentSubscriptions.CreateReq.Options
end

defmodule EventStore.Client.PersistentSubscriptions.CreateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.PersistentSubscriptions.UpdateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil,
          group_name: String.t(),
          settings: EventStore.Client.PersistentSubscriptions.UpdateReq.Settings.t() | nil
        }

  defstruct [:stream_identifier, :group_name, :settings]

  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :group_name, 2, type: :string
  field :settings, 3, type: EventStore.Client.PersistentSubscriptions.UpdateReq.Settings
end

defmodule EventStore.Client.PersistentSubscriptions.UpdateReq.Settings do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          message_timeout: {atom, any},
          checkpoint_after: {atom, any},
          resolve_links: boolean,
          revision: non_neg_integer,
          extra_statistics: boolean,
          max_retry_count: integer,
          min_checkpoint_count: integer,
          max_checkpoint_count: integer,
          max_subscriber_count: integer,
          live_buffer_size: integer,
          read_batch_size: integer,
          history_buffer_size: integer,
          named_consumer_strategy:
            EventStore.Client.PersistentSubscriptions.UpdateReq.ConsumerStrategy.t()
        }

  defstruct [
    :message_timeout,
    :checkpoint_after,
    :resolve_links,
    :revision,
    :extra_statistics,
    :max_retry_count,
    :min_checkpoint_count,
    :max_checkpoint_count,
    :max_subscriber_count,
    :live_buffer_size,
    :read_batch_size,
    :history_buffer_size,
    :named_consumer_strategy
  ]

  oneof :message_timeout, 0
  oneof :checkpoint_after, 1
  field :resolve_links, 1, type: :bool
  field :revision, 2, type: :uint64
  field :extra_statistics, 3, type: :bool
  field :max_retry_count, 5, type: :int32
  field :min_checkpoint_count, 7, type: :int32
  field :max_checkpoint_count, 8, type: :int32
  field :max_subscriber_count, 9, type: :int32
  field :live_buffer_size, 10, type: :int32
  field :read_batch_size, 11, type: :int32
  field :history_buffer_size, 12, type: :int32

  field :named_consumer_strategy, 13,
    type: EventStore.Client.PersistentSubscriptions.UpdateReq.ConsumerStrategy,
    enum: true

  field :message_timeout_ticks, 4, type: :int64, oneof: 0
  field :message_timeout_ms, 14, type: :int32, oneof: 0
  field :checkpoint_after_ticks, 6, type: :int64, oneof: 1
  field :checkpoint_after_ms, 15, type: :int32, oneof: 1
end

defmodule EventStore.Client.PersistentSubscriptions.UpdateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.PersistentSubscriptions.UpdateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.PersistentSubscriptions.UpdateReq.Options
end

defmodule EventStore.Client.PersistentSubscriptions.UpdateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.PersistentSubscriptions.DeleteReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil,
          group_name: String.t()
        }

  defstruct [:stream_identifier, :group_name]

  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :group_name, 2, type: :string
end

defmodule EventStore.Client.PersistentSubscriptions.DeleteReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.PersistentSubscriptions.DeleteReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.PersistentSubscriptions.DeleteReq.Options
end

defmodule EventStore.Client.PersistentSubscriptions.DeleteResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.PersistentSubscriptions.PersistentSubscriptions.Service do
  @moduledoc false
  use Spear.Service, name: "event_store.client.persistent_subscriptions.PersistentSubscriptions"

  rpc :Create,
      EventStore.Client.PersistentSubscriptions.CreateReq,
      EventStore.Client.PersistentSubscriptions.CreateResp

  rpc :Update,
      EventStore.Client.PersistentSubscriptions.UpdateReq,
      EventStore.Client.PersistentSubscriptions.UpdateResp

  rpc :Delete,
      EventStore.Client.PersistentSubscriptions.DeleteReq,
      EventStore.Client.PersistentSubscriptions.DeleteResp

  rpc :Read,
      stream(EventStore.Client.PersistentSubscriptions.ReadReq),
      stream(EventStore.Client.PersistentSubscriptions.ReadResp)
end
