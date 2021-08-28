defmodule Spear.Position do
  @moduledoc """
  A data structure representing a position in the `$all` stream
  """

  require Spear.Records.Shared, as: Shared

  @typedoc """
  A struct representing the prepare and commit positions for an event in the
  `$all` stream
  """
  @type t :: %__MODULE__{commit: integer(), prepare: integer()}

  defstruct [:commit, :prepare]

  @doc false
  def from_record(Shared.all_stream_position(commit_position: commit, prepare_position: prepare)) do
    %__MODULE__{commit: commit, prepare: prepare}
  end
end
