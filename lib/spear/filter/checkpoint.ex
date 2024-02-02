defmodule Spear.Filter.Checkpoint do
  @moduledoc """
  A struct representing a checkpoint in server-side filtering
  """

  require Spear.Records.Streams, as: Streams

  @typedoc """
  A struct representing a checkpoint in a server-side filter operation

  When subscribing to the `:all` stream, one may provide a `:filter` option
  which the server will use to filter events before sending them over the
  network.

  Since the results of a server-side filtering subscription can be sparsely
  spread out in the entire `:all` stream, the EventStoreDB emits checkpoints
  as it reads through the events.

  A client can restore its position in a filter subscription by passing
  one of these structs to the `:from` option of `Spear.subscribe/4`.

  See the `Spear.Filter` documentation for more information.
  """
  @typedoc since: "0.1.0"
  @type t :: %__MODULE__{
          commit_position: non_neg_integer(),
          prepare_position: non_neg_integer(),
          subscription: reference()
        }

  defstruct [:commit_position, :prepare_position, :subscription]

  @doc false
  # coveralls-ignore-start
  def from_read_response(
        Streams.read_resp(
          content:
            {:checkpoint,
             Streams.read_resp_checkpoint(commit_position: commit, prepare_position: prepare)}
        ),
        subscription
      ) do
    %__MODULE__{
      commit_position: commit,
      prepare_position: prepare,
      subscription: subscription
    }
  end

  # coveralls-ignore-stop
end
