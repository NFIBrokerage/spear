defmodule Spear.Position do
  @moduledoc """
  A data structure representing a position in the `$all` stream
  """
  @moduledoc since: "0.10.0"

  require Spear.Records.Shared, as: Shared

  @typedoc """
  A struct representing the prepare and commit positions for an event in the
  `$all` stream
  """
  @typedoc since: "0.10.0"
  @type t :: %__MODULE__{commit: integer(), prepare: integer()}

  defstruct [:commit, :prepare]

  @doc false
  def from_record(Shared.all_stream_position(commit_position: commit, prepare_position: prepare)) do
    %__MODULE__{commit: commit, prepare: prepare}
  end
end
