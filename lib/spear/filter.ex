defmodule Spear.Filter do
  @moduledoc """
  A server-side filter to apply when reading events from an EventStore

  ## Regular expressions

  Elixir's built-in `Regex` module and `Kernel.sigil_r/2`
  use PCRE-compatible regular expressions, but from [the EventStore
  codebase](https://github.com/EventStore/EventStore/commit/711a8622569cdee3b182a4bb0d2a32ab0c950a73#diff-f444f5f2feccef613b5a027880c6f810defd43d2f882b6b6a9c0612e50ca873aR3)
  it seems that at time of writing, filtering is done with C-sharp's
  `System.Text.RegularExpressions` built-in. C-sharp regular expressions
  diverge in syntax a bit from PCRE-compatible expressions, so mileage may
  vary when passing Elixir regular expressions.

  As an escape hatch, you may build a `t:Spear.Filter.t/0` manually and use
  a `t:String.t/0` as the `:by` field. This value will be untouched except
  for last-minute encoding to go over-the-wire to the server.

  ```elixir
  %Spear.Filter{
    on: :stream_name,
    by: "<some-complicated-regex>",
    checkpoint_after: 1024
  }
  ```

  If possible, the list of prefixes should be used as the `:by` option as
  they are unambiguous and anecdotally seem faster.

  ## Checkpoints

  The EventStore will emit checkpoint events to a subscriber regularly.

  This prevents a possible (and perhaps probable) scenario where

  - the EventStore contains many events
  - the client is searching for a small number of events relative to the size
    of `:all`
  - (and/or) the target events are sparsely spread throughout `:all`

  Under these conditions, the EventStore may progress through `:all` quite a
  ways before finding an event. If the connection is severed between the client
  and server while the EventStore is part-way through a large drought of
  targeted events, the server will need to re-seek through the drought
  when the client re-connects and passes an old `:from` option to
  `Spear.subscribe/4`.

  These checkpoints will arrive in the mailbox of the subscriber process as
  `t:Spear.Filter.Checkpoint.t/0` structs and may be used as a restore point
  by passing them to the `:from` option of `Spear.subscribe/4`.

  For example, say we have a subscriber process which is a GenServer and some
  function `save_checkpoint/1` which saves checkpoint information durably
  (to disk or a database for example). It will handle subscription events
  in its `c:GenServer.handle_info/2` callback.

  ```elixir
  defmodule MySubscriber do
    use GenServer

    alias Spear.{Event, Filter.Checkpoint}

    ..

    @impl GenServer
    def handle_info(%Event{} = event, state) do
      # .. handle the event

      event |> Event.to_checkpoint() |> save_checkpoint()

      {:noreply, state}
    end

    def handle_info(%Checkpoint{} = checkpoint, state) do
      save_checkpoint(checkpoint)

      {:noreply, state}
    end
  end
  ```

  ## Checkpoint Interval

  The EventStore will send a checkpoint after filtering a configurable number
  of events. The `:checkpoint_after` field can be used to configure this
  behavior. Note that the `:checkpoint_after` is only allowed by the server
  to be a multiple of `32`. Other values will be rounded to the nearest
  multiple.

  The default is set at `1024` (`32` * `32`) in Spear but this is tunable
  per filter with `checkpoint_after/2`, or by manually adjusting the
  `:checkpoint_after` field in this struct.
  """

  alias Spear.Protos.EventStore.Client.{
    Streams.ReadReq.Options.FilterOptions,
    Shared.Empty
  }

  @checkpoint_multiplier 32
  @default_checkpoint_after 32 * @checkpoint_multiplier

  @typedoc """
  A filter which can be applied to a subscription to trigger server-side
  result filtering

  This filter type is intended to be passed as the `:filter` option to
  `Spear.subscribe/4`.

  ## Examples

      iex> import Spear.Filter
      iex> filter = ~f/^[^\\$].*/rs # exclude system events which start with "$"
      %Spear.Filter{by: ~r/^[^\\$].*/, checkpoint_after: 1024, on: :stream_name}
  """
  @type t :: %__MODULE__{
          on: :event_type | :stream_name,
          by: Regex.t() | String.t() | [String.t()],
          checkpoint_after: pos_integer()
        }

  defstruct [:on, :by, checkpoint_after: @default_checkpoint_after]

  @doc """
  A sigil defining short-hand notation for writing filters

  Filters may either filter _on_ EventStore stream name or event type and may
  either filter _by_ a regular expression or a list of prefix strings.

  ## Modifiers

  This `f` sigil supports the following modifiers. (Note that modifiers are
  the suffix of the sigil. E.g. the `i` in `~r/hello/i` is a modifier for
  the regex sigil that declares that the match is case-insensitive.)

  For the choice between stream-name and event-type filtering:

  * `s` - filter on the stream name
  * `t` - filter on the event type

  For the choice between prefixes and regular expressions:

  * `p` - filter by a list of prefixes. If this option is passed the sigil
    body will be interpreted as a white-space separated list of prefixes
    similar to `sigil_w/2` from the standard library
  * `r` - filter using a regular expression

  ## Examples

      iex> import Spear.Filter
      iex> ~f/My.Aggregate.A- My.Aggregate.B-/ps
      %Spear.Filter{
        by: ["My.Aggregate.A-", "My.Aggregate.B-"],
        checkpoint_after: 1024,
        on: :stream_name
      }
      iex> ~f/^[^\\$].*/rs
      %Spear.Filter{by: ~r/^[^\\$].*/, checkpoint_after: 1024, on: :stream_name}
  """
  @spec sigil_f(binary(), charlist()) :: t()
  def sigil_f(source, mods) do
    to_filter(source, mods)
  end

  @doc """
  A sigil defining a filter, without escaping

  Works the same as `sigil_f/2` but does not allow interpolation or escape
  sequences.
  """
  @spec sigil_F(binary(), charlist()) :: t()
  def sigil_F(source, mods) do
    to_filter(source, mods)
  end

  defp to_filter(source, mods) when is_binary(source) and is_list(mods) do
    :ok = check_modifiers!(source, mods)

    on = if Enum.find(mods, &(&1 in [?s, ?t])) == ?t, do: :event_type, else: :stream_name

    by =
      case Enum.find(mods, &(&1 in [?p, ?r])) do
        ?p -> String.split(source)
        _ -> Regex.compile!(source)
      end

    %__MODULE__{on: on, by: by}
  end

  defp check_modifiers!(source, mods) do
    sigil = "~f/#{source}/#{mods}"

    foreign_modifiers =
      mods
      |> Enum.reject(&(&1 in [?s, ?t, ?p, ?r]))
      |> Enum.uniq()

    cond do
      foreign_modifiers != [] ->
        raise ArgumentError, """
        Unknown modifier(s) #{inspect(foreign_modifiers)} in #{sigil}
        """

      Enum.member?(mods, ?s) and Enum.member?(mods, ?t) ->
        raise ArgumentError, """
        Modifiers `s` and `t` are mutually exclusive in sigil #{sigil}
        """

      Enum.member?(mods, ?p) and Enum.member?(mods, ?r) ->
        raise ArgumentError, """
        Modifiers `p` and `r` are mutually exclusive in sigil #{sigil}
        """

      true ->
        :ok
    end
  end

  @doc """
  Sets the checkpoint interval

  ## Examples

      iex> import Spear.Filter
      iex> checkpoint_after(~f/^[^\\$].*/rs, 32 * 8)
      %Spear.Filter{by: ~r/^[^\\$].*/, checkpoint_after: 256, on: :stream_name}
  """
  @spec checkpoint_after(t(), pos_integer()) :: t()
  def checkpoint_after(%__MODULE__{} = filter, interval)
      when is_integer(interval) and interval > 0 do
    %__MODULE__{filter | checkpoint_after: interval}
  end

  @doc """
  Produces a filter which excludes system events

  This is a potentially common filter for subscribers reading from `:all`.

  The `sigil_f/2` version is

  ```elixir
  ~f/^[^\\$].*/rs
  ```

  ## Examples

      iex> Spear.Filter.exclude_system_events()
      %Spear.Filter{by: ~r/^[^\\$].*/, checkpoint_after: 1024, on: :stream_name}
  """
  @spec exclude_system_events() :: t()
  def exclude_system_events, do: ~f/^[^\$].*/rs

  @doc false
  def _to_filter_options(%__MODULE__{} = filter) do
    %FilterOptions{
      checkpointIntervalMultiplier: div(filter.checkpoint_after, @checkpoint_multiplier),
      filter: map_inner_filter(filter),
      # YARD exactly how does one use the `:max` option here?
      window: {:count, %Empty{}}
    }
  end

  defp map_inner_filter(%__MODULE__{} = filter) do
    {map_filter_type(filter.on), map_filter_expression(filter.by)}
  end

  defp map_filter_type(:event_type), do: :event_type
  defp map_filter_type(:stream_name), do: :stream_name

  defp map_filter_expression(%Regex{} = regex) do
    regex |> Regex.source() |> map_filter_expression()
  end

  defp map_filter_expression(regex) when is_binary(regex) do
    %FilterOptions.Expression{regex: regex, prefix: nil}
  end

  defp map_filter_expression(prefixes) when is_list(prefixes) do
    %FilterOptions.Expression{regex: nil, prefix: prefixes}
  end
end

# IMHO this is a bit unnecessary and really just makes it harder to read
#
# defimpl Inspect, for: Spear.Filter do
#   def inspect(filter, opts) do
#     {escaped, _} =
#       filter
#       |> body()
#       |> Code.Identifier.escape(?/)
# 
#     ["~f/", escaped, ?/, opts(filter)]
#     |> IO.iodata_to_binary()
#     |> Inspect.Algebra.color(:regex, opts)
#   end
#
#   defp body(%Spear.Filter{by: prefixes}) when is_list(prefixes), do: Enum.join(prefixes, " ")
#   defp body(%Spear.Filter{by: %Regex{} = regex}), do: Regex.source(regex)
#   defp body(%Spear.Filter{by: other}), do: to_string(other)
# 
#   defp opts(%Spear.Filter{by: by, on: on}) do
#     [by_opt(by), on_opt(on)]
#   end
#
#   defp on_opt(:event_type), do: ?t
#   defp on_opt(:stream_name), do: ?s
#   defp on_opt(_), do: []
#
#   defp by_opt(prefixes) when is_list(prefixes), do: ?p
#   defp by_opt(%Regex{}), do: ?r
#   defp by_opt(regex) when is_binary(regex), do: ?r
#   defp by_opt(_), do: []
# end
