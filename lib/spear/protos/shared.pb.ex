alias Spear.Protos.EventStore

defmodule EventStore.Client.Shared.UUID.Structured do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          most_significant_bits: integer,
          least_significant_bits: integer
        }

  defstruct [:most_significant_bits, :least_significant_bits]

  field :most_significant_bits, 1, type: :int64
  field :least_significant_bits, 2, type: :int64
end

defmodule EventStore.Client.Shared.UUID do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          value: {atom, any}
        }

  defstruct [:value]

  oneof :value, 0
  field :structured, 1, type: EventStore.Client.Shared.UUID.Structured, oneof: 0
  field :string, 2, type: :string, oneof: 0
end

defmodule EventStore.Client.Shared.Empty do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Shared.StreamIdentifier do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          streamName: binary
        }

  defstruct [:streamName]

  field :streamName, 3, type: :bytes
end
