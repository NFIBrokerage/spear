defmodule Spear.Records.Google do
  @moduledoc """
  A record-like wrapper around google protobufs
  """

  defmacro empty do
    quote do
      {:"google.protobuf.Empty"}
    end
  end

  if Version.match?(System.version(), ">= 1.11.0") do
    def timestamp(%DateTime{} = datetime) do
      # google timestamp is number of seconds from the first second of 1970 (smeared)
      update_in(datetime.year, &(&1 - 1970))
      |> DateTime.to_gregorian_seconds()
      |> timestamp()
    end
  end

  def timestamp({seconds, nanos}) do
    {:"google.protobuf.Timestamp", seconds, nanos}
  end
end
