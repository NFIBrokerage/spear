defmodule Spear.Filter.Checkpoint do
  @moduledoc """
  A struct representing a checkpoint in server-side filtering
  """

  alias Spear.Protos.EventStore.Client.Streams.ReadResp

  @typedoc """
  A struct representing a checkpoint in a server-side filter operation

  When subscribing to the `:all` stream, one may provide a `:filter` option
  which the server will use to filter events before sending them over the
  network.

  Since the results of a server-side filtering subscription can be sparsely
  spread out in the entire `:all` stream, the EventStore emits checkpoints
  as it reads through the events.

  A client can restore its position in a filter subscription by passing
  one of these structs to the `:from` option of `Spear.subscribe/4`.

  See the `Spear.Filter` documentation for more information.
  """
  @type t :: %__MODULE__{
          commit_position: non_neg_integer(),
          prepare_position: non_neg_integer()
        }

  defstruct [:commit_position, :prepare_position]

  @doc false
  def from_read_response(%ReadResp{
        content:
          {:checkpoint, %ReadResp.Checkpoint{commit_position: commit, prepare_position: prepare}}
      }) do
    %__MODULE__{commit_position: commit, prepare_position: prepare}
  end
end