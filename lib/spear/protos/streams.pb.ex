alias Spear.Protos.EventStore

defmodule EventStore.Client.Streams.ReadReq.Options.ReadDirection do
  @moduledoc false
  use Protobuf, enum: true, syntax: :proto3
  @type t :: integer | :Forwards | :Backwards

  field :Forwards, 0

  field :Backwards, 1
end

defmodule EventStore.Client.Streams.ReadReq.Options.StreamOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          revision_option: {atom, any},
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil
        }

  defstruct [:revision_option, :stream_identifier]

  oneof :revision_option, 0
  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :revision, 2, type: :uint64, oneof: 0
  field :start, 3, type: EventStore.Client.Shared.Empty, oneof: 0
  field :end, 4, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.ReadReq.Options.AllOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          all_option: {atom, any}
        }

  defstruct [:all_option]

  oneof :all_option, 0
  field :position, 1, type: EventStore.Client.Streams.ReadReq.Options.Position, oneof: 0
  field :start, 2, type: EventStore.Client.Shared.Empty, oneof: 0
  field :end, 3, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.ReadReq.Options.SubscriptionOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Streams.ReadReq.Options.Position do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit_position: non_neg_integer,
          prepare_position: non_neg_integer
        }

  defstruct [:commit_position, :prepare_position]

  field :commit_position, 1, type: :uint64
  field :prepare_position, 2, type: :uint64
end

defmodule EventStore.Client.Streams.ReadReq.Options.FilterOptions.Expression do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          regex: String.t(),
          prefix: [String.t()]
        }

  defstruct [:regex, :prefix]

  field :regex, 1, type: :string
  field :prefix, 2, repeated: true, type: :string
end

defmodule EventStore.Client.Streams.ReadReq.Options.FilterOptions do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          filter: {atom, any},
          window: {atom, any},
          checkpointIntervalMultiplier: non_neg_integer
        }

  defstruct [:filter, :window, :checkpointIntervalMultiplier]

  oneof :filter, 0
  oneof :window, 1

  field :stream_identifier, 1,
    type: EventStore.Client.Streams.ReadReq.Options.FilterOptions.Expression,
    oneof: 0

  field :event_type, 2,
    type: EventStore.Client.Streams.ReadReq.Options.FilterOptions.Expression,
    oneof: 0

  field :max, 3, type: :uint32, oneof: 1
  field :count, 4, type: EventStore.Client.Shared.Empty, oneof: 1
  field :checkpointIntervalMultiplier, 5, type: :uint32
end

defmodule EventStore.Client.Streams.ReadReq.Options.UUIDOption do
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

defmodule EventStore.Client.Streams.ReadReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_option: {atom, any},
          count_option: {atom, any},
          filter_option: {atom, any},
          read_direction: EventStore.Client.Streams.ReadReq.Options.ReadDirection.t(),
          resolve_links: boolean,
          uuid_option: EventStore.Client.Streams.ReadReq.Options.UUIDOption.t() | nil
        }

  defstruct [
    :stream_option,
    :count_option,
    :filter_option,
    :read_direction,
    :resolve_links,
    :uuid_option
  ]

  oneof :stream_option, 0
  oneof :count_option, 1
  oneof :filter_option, 2
  field :stream, 1, type: EventStore.Client.Streams.ReadReq.Options.StreamOptions, oneof: 0
  field :all, 2, type: EventStore.Client.Streams.ReadReq.Options.AllOptions, oneof: 0

  field :read_direction, 3,
    type: EventStore.Client.Streams.ReadReq.Options.ReadDirection,
    enum: true

  field :resolve_links, 4, type: :bool
  field :count, 5, type: :uint64, oneof: 1

  field :subscription, 6,
    type: EventStore.Client.Streams.ReadReq.Options.SubscriptionOptions,
    oneof: 1

  field :filter, 7, type: EventStore.Client.Streams.ReadReq.Options.FilterOptions, oneof: 2
  field :no_filter, 8, type: EventStore.Client.Shared.Empty, oneof: 2
  field :uuid_option, 9, type: EventStore.Client.Streams.ReadReq.Options.UUIDOption
end

defmodule EventStore.Client.Streams.ReadReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @behaviour Spear.TypedMessage

  @type t :: %__MODULE__{
          options: EventStore.Client.Streams.ReadReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Streams.ReadReq.Options

  @impl Spear.TypedMessage
  def message_type, do: "event_store.client.streams.ReadReq"
end

defmodule EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent.MetadataEntry do
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

defmodule EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent do
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
    type: EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent.MetadataEntry,
    map: true

  field :custom_metadata, 7, type: :bytes
  field :data, 8, type: :bytes
end

defmodule EventStore.Client.Streams.ReadResp.ReadEvent do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          position: {atom, any},
          event: EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent.t() | nil,
          link: EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent.t() | nil
        }

  defstruct [:position, :event, :link]

  oneof :position, 0
  field :event, 1, type: EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent
  field :link, 2, type: EventStore.Client.Streams.ReadResp.ReadEvent.RecordedEvent
  field :commit_position, 3, type: :uint64, oneof: 0
  field :no_position, 4, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.ReadResp.SubscriptionConfirmation do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          subscription_id: String.t()
        }

  defstruct [:subscription_id]

  field :subscription_id, 1, type: :string
end

defmodule EventStore.Client.Streams.ReadResp.Checkpoint do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit_position: non_neg_integer,
          prepare_position: non_neg_integer
        }

  defstruct [:commit_position, :prepare_position]

  field :commit_position, 1, type: :uint64
  field :prepare_position, 2, type: :uint64
end

defmodule EventStore.Client.Streams.ReadResp.StreamNotFound do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil
        }

  defstruct [:stream_identifier]

  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
end

defmodule EventStore.Client.Streams.ReadResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: {atom, any}
        }

  defstruct [:content]

  oneof :content, 0
  field :event, 1, type: EventStore.Client.Streams.ReadResp.ReadEvent, oneof: 0

  field :confirmation, 2,
    type: EventStore.Client.Streams.ReadResp.SubscriptionConfirmation,
    oneof: 0

  field :checkpoint, 3, type: EventStore.Client.Streams.ReadResp.Checkpoint, oneof: 0
  field :stream_not_found, 4, type: EventStore.Client.Streams.ReadResp.StreamNotFound, oneof: 0
end

defmodule EventStore.Client.Streams.AppendReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          expected_stream_revision: {atom, any},
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil
        }

  defstruct [:expected_stream_revision, :stream_identifier]

  oneof :expected_stream_revision, 0
  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :revision, 2, type: :uint64, oneof: 0
  field :no_stream, 3, type: EventStore.Client.Shared.Empty, oneof: 0
  field :any, 4, type: EventStore.Client.Shared.Empty, oneof: 0
  field :stream_exists, 5, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.AppendReq.ProposedMessage.MetadataEntry do
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

defmodule EventStore.Client.Streams.AppendReq.ProposedMessage do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          id: EventStore.Client.Shared.UUID.t() | nil,
          metadata: %{String.t() => String.t()},
          custom_metadata: binary,
          data: binary
        }

  defstruct [:id, :metadata, :custom_metadata, :data]

  field :id, 1, type: EventStore.Client.Shared.UUID

  field :metadata, 2,
    repeated: true,
    type: EventStore.Client.Streams.AppendReq.ProposedMessage.MetadataEntry,
    map: true

  field :custom_metadata, 3, type: :bytes
  field :data, 4, type: :bytes
end

defmodule EventStore.Client.Streams.AppendReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          content: {atom, any}
        }

  @behaviour Spear.TypedMessage

  defstruct [:content]

  oneof :content, 0
  field :options, 1, type: EventStore.Client.Streams.AppendReq.Options, oneof: 0
  field :proposed_message, 2, type: EventStore.Client.Streams.AppendReq.ProposedMessage, oneof: 0

  @impl Spear.TypedMessage
  def message_type, do: "event_store.client.streams.AppendReq"
end

defmodule EventStore.Client.Streams.AppendResp.Position do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit_position: non_neg_integer,
          prepare_position: non_neg_integer
        }

  defstruct [:commit_position, :prepare_position]

  field :commit_position, 1, type: :uint64
  field :prepare_position, 2, type: :uint64
end

defmodule EventStore.Client.Streams.AppendResp.Success do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          current_revision_option: {atom, any},
          position_option: {atom, any}
        }

  defstruct [:current_revision_option, :position_option]

  oneof :current_revision_option, 0
  oneof :position_option, 1
  field :current_revision, 1, type: :uint64, oneof: 0
  field :no_stream, 2, type: EventStore.Client.Shared.Empty, oneof: 0
  field :position, 3, type: EventStore.Client.Streams.AppendResp.Position, oneof: 1
  field :no_position, 4, type: EventStore.Client.Shared.Empty, oneof: 1
end

defmodule EventStore.Client.Streams.AppendResp.WrongExpectedVersion do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          current_revision_option_20_6_0: {atom, any},
          expected_revision_option_20_6_0: {atom, any},
          current_revision_option: {atom, any},
          expected_revision_option: {atom, any}
        }

  defstruct [
    :current_revision_option_20_6_0,
    :expected_revision_option_20_6_0,
    :current_revision_option,
    :expected_revision_option
  ]

  oneof :current_revision_option_20_6_0, 0
  oneof :expected_revision_option_20_6_0, 1
  oneof :current_revision_option, 2
  oneof :expected_revision_option, 3
  field :current_revision_20_6_0, 1, type: :uint64, oneof: 0
  field :no_stream_20_6_0, 2, type: EventStore.Client.Shared.Empty, oneof: 0
  field :expected_revision_20_6_0, 3, type: :uint64, oneof: 1
  field :any_20_6_0, 4, type: EventStore.Client.Shared.Empty, oneof: 1
  field :stream_exists_20_6_0, 5, type: EventStore.Client.Shared.Empty, oneof: 1
  field :current_revision, 6, type: :uint64, oneof: 2
  field :current_no_stream, 7, type: EventStore.Client.Shared.Empty, oneof: 2
  field :expected_revision, 8, type: :uint64, oneof: 3
  field :expected_any, 9, type: EventStore.Client.Shared.Empty, oneof: 3
  field :expected_stream_exists, 10, type: EventStore.Client.Shared.Empty, oneof: 3
  field :expected_no_stream, 11, type: EventStore.Client.Shared.Empty, oneof: 3
end

defmodule EventStore.Client.Streams.AppendResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          result: {atom, any}
        }

  defstruct [:result]

  oneof :result, 0
  field :success, 1, type: EventStore.Client.Streams.AppendResp.Success, oneof: 0

  field :wrong_expected_version, 2,
    type: EventStore.Client.Streams.AppendResp.WrongExpectedVersion,
    oneof: 0
end

defmodule EventStore.Client.Streams.DeleteReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          expected_stream_revision: {atom, any},
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil
        }

  defstruct [:expected_stream_revision, :stream_identifier]

  oneof :expected_stream_revision, 0
  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :revision, 2, type: :uint64, oneof: 0
  field :no_stream, 3, type: EventStore.Client.Shared.Empty, oneof: 0
  field :any, 4, type: EventStore.Client.Shared.Empty, oneof: 0
  field :stream_exists, 5, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.DeleteReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Streams.DeleteReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Streams.DeleteReq.Options
end

defmodule EventStore.Client.Streams.DeleteResp.Position do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit_position: non_neg_integer,
          prepare_position: non_neg_integer
        }

  defstruct [:commit_position, :prepare_position]

  field :commit_position, 1, type: :uint64
  field :prepare_position, 2, type: :uint64
end

defmodule EventStore.Client.Streams.DeleteResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          position_option: {atom, any}
        }

  defstruct [:position_option]

  oneof :position_option, 0
  field :position, 1, type: EventStore.Client.Streams.DeleteResp.Position, oneof: 0
  field :no_position, 2, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.TombstoneReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          expected_stream_revision: {atom, any},
          stream_identifier: EventStore.Client.Shared.StreamIdentifier.t() | nil
        }

  defstruct [:expected_stream_revision, :stream_identifier]

  oneof :expected_stream_revision, 0
  field :stream_identifier, 1, type: EventStore.Client.Shared.StreamIdentifier
  field :revision, 2, type: :uint64, oneof: 0
  field :no_stream, 3, type: EventStore.Client.Shared.Empty, oneof: 0
  field :any, 4, type: EventStore.Client.Shared.Empty, oneof: 0
  field :stream_exists, 5, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.TombstoneReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Streams.TombstoneReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Streams.TombstoneReq.Options
end

defmodule EventStore.Client.Streams.TombstoneResp.Position do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          commit_position: non_neg_integer,
          prepare_position: non_neg_integer
        }

  defstruct [:commit_position, :prepare_position]

  field :commit_position, 1, type: :uint64
  field :prepare_position, 2, type: :uint64
end

defmodule EventStore.Client.Streams.TombstoneResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          position_option: {atom, any}
        }

  defstruct [:position_option]

  oneof :position_option, 0
  field :position, 1, type: EventStore.Client.Streams.TombstoneResp.Position, oneof: 0
  field :no_position, 2, type: EventStore.Client.Shared.Empty, oneof: 0
end

defmodule EventStore.Client.Streams.Streams.Service do
  @moduledoc false
  use Spear.Service, name: "event_store.client.streams.Streams"

  rpc :Read, EventStore.Client.Streams.ReadReq, stream(EventStore.Client.Streams.ReadResp)

  rpc :Append, stream(EventStore.Client.Streams.AppendReq), EventStore.Client.Streams.AppendResp

  rpc :Delete, EventStore.Client.Streams.DeleteReq, EventStore.Client.Streams.DeleteResp

  rpc :Tombstone, EventStore.Client.Streams.TombstoneReq, EventStore.Client.Streams.TombstoneResp
end
