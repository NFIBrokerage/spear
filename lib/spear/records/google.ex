defmodule Spear.Records.Google do
  @moduledoc """
  A record-like wrapper around google protobufs
  """

  defmacro empty do
    quote do
      {:"google.protobuf.Empty"}
    end
  end

  # message Timestamp {
  #   // Represents seconds of UTC time since Unix epoch
  #   // 1970-01-01T00:00:00Z. Must be from 0001-01-01T00:00:00Z to
  #   // 9999-12-31T23:59:59Z inclusive.
  #   int64 seconds = 1;
  #
  #   // Non-negative fractions of a second at nanosecond resolution. Negative
  #   // second values with fractions must still have non-negative nanos values
  #   // that count forward in time. Must be from 0 to 999,999,999
  #   // inclusive.
  #   int32 nanos = 2;
  # }
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

  # message Duration {
  #   // Signed seconds of the span of time. Must be from -315,576,000,000
  #   // to +315,576,000,000 inclusive. Note: these bounds are computed from:
  #   // 60 sec/min * 60 min/hr * 24 hr/day * 365.25 days/year * 10000 years
  #   int64 seconds = 1;
  #
  #   // Signed fractions of a second at nanosecond resolution of the span
  #   // of time. Durations less than one second are represented with a 0
  #   // `seconds` field and a positive or negative `nanos` field. For durations
  #   // of one second or more, a non-zero value for the `nanos` field must be
  #   // of the same sign as the `seconds` field. Must be from -999,999,999
  #   // to +999,999,999 inclusive.
  #   int32 nanos = 2;
  # }
  def duration(seconds, nanos) do
    {:"google.protobuf.Duration", seconds, nanos}
  end
end
