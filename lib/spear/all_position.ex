defmodule Spear.AllPosition do
  @moduledoc """
  A data structure representing a position in the `$all` stream
  """

  require Spear.Records.Shared, as: Shared

  @type t :: %__MODULE__{commit: integer(), prepare: integer()}

  defstruct [:commit, :prepare]

  def from_record(Shared.all_stream_position(commit_position: commit, prepare_position: prepare)) do
    %__MODULE__{commit: commit, prepare: prepare}
  end
end
