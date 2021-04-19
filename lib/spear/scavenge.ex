defmodule Spear.Scavenge do
  @moduledoc """
  A struct representing a scavenge and its progress
  """
  @moduledoc since: "0.4.0"

  import Spear.Records.Operations, only: [scavenge_resp: 1]

  @typedoc """
  The result of starting or stopping a scavenge

  This structure does not represent the current status of a scavenge. The
  scavenge stream (`Spear.scavenge_stream/1`) may be read to determine the
  current status of a scavenge.

  ## Examples

      iex> {:ok, scavenge} = Spear.start_scavenge(conn)
      {:ok,
       %Spear.Scavenge{id: "d2897ba8-2f0c-4fc4-bb25-798ba75f3562", result: :Started}}
  """
  @typedoc since: "0.4.0"
  @type t :: %__MODULE__{id: String.t(), result: :Started | :InProgress | :Stopped}

  defstruct [:id, :result]

  @doc false
  def from_scavenge_resp(scavenge_resp(scavenge_id: id, scavenge_result: result)) do
    %__MODULE__{id: id, result: result}
  end
end
