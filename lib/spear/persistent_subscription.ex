defmodule Spear.PersistentSubscription do
  @moduledoc """
  A struct representing a persistent subscription and its settings
  """

  require Spear.Records.Shared, as: Shared
  require Spear.Records.Persistent, as: Persistent

  @typedoc """
  The action the EventStoreDB should take for an event's nack

  * `:park` - stops the EventStoreDB from re-sending the event and appends a
    reference to the event to the persistent subscription's parked events
    stream. These events can be retried later by clicking the "Replay
    Parked Messages" button in the EventStoreDB dashboard's persistent
    subscriptions section for each stream+group combination. The EventStoreDB
    parking system is conceptually similar to dead letter queues.
  * `:retry` - retries the event up to `:max_retry_count` tries. This option is
    a reasonable default so that if a consumer hits a transient error condition
    such as a network timeout, it will retry the event before giving up and
    parking. Note that once a consumer has retried an event more than
    `:max_retry_count` times, the event is parked, even if the `:retry` action
    is given to `Spear.nack/4`.
  * `:skip` - skips the event without moving it to the parked events stream.
    Practically this is no different than simply `Spear.ack/3`ing the event(s)
    and performing a no-op in the consumer. Skipping may be a good option for
    dealing with poison messages: malformed or otherwise completely
    unhandleable events.
  """
  @typedoc since: "0.6.0"
  @type nack_action :: :unknown | :park | :retry | :skip

  @typedoc """
  A persistent subscription.

  These are generally returned from `Spear.list_persistent_subscriptions/2`.

  Persistent subscriptions are considered unique by their stream name and
  group name pairings. A stream may have many different persistent
  subscriptions with different group names and settings and a group name
  may be used for multiple subscriptions to different streams.

  ## Examples

      iex> Spear.create_persistent_subscription(conn, "my_stream", "my_group", %Spear.PersistentSubscription.Settings{})
      :ok
      iex> {:ok, subscriptions} = Spear.list_persistent_subscriptions(conn)
      iex> subscriptions |> Enum.to_list()
      [
        %Spear.PersistentSubscription{
          group_name: "my_group",
          settings: %Spear.PersistentSubscription.Settings{
            checkpoint_after: 3000,
            extra_statistics?: nil,
            history_buffer_size: 300,
            live_buffer_size: 100,
            max_checkpoint_count: 100,
            max_retry_count: 10,
            max_subscriber_count: 1,
            message_timeout: 5000,
            min_checkpoint_count: 1,
            named_consumer_strategy: :RoundRobin,
            read_batch_size: 100,
            resolve_links?: true,
            revision: 0
          },
          stream_name: "my_stream"
        }
      ]
  """
  @typedoc since: "0.6.0"
  @type t :: %__MODULE__{
          stream_name: String.t(),
          group_name: String.t(),
          settings: Spear.PersistentSubscription.Settings.t()
        }

  defstruct ~w[stream_name group_name settings]a

  @doc false
  def from_map(map) do
    %__MODULE__{
      stream_name: map_stream_name(map["stream"]),
      group_name: map["group"],
      settings: %Spear.PersistentSubscription.Settings{
        resolve_links?: map["resolveLinkTos"],
        extra_statistics?: nil,
        message_timeout: map["messageTimeout"],
        live_buffer_size: map["liveBufferSize"],
        history_buffer_size: map["historyBufferSize"],
        max_retry_count: map["maxRetryCount"],
        read_batch_size: map["readBatchSize"],
        checkpoint_after: map["checkPointAfter"],
        min_checkpoint_count: map["minCheckPointCount"],
        max_checkpoint_count: map["maxCheckPointCount"],
        max_subscriber_count: map["maxSubscriberCount"],
        named_consumer_strategy: map["namedConsumerStrategy"] |> to_atom()
      }
    }
  end

  defp to_atom(string) when is_binary(string), do: String.to_atom(string)
  defp to_atom(_), do: nil

  defp map_stream_name("$all"), do: :all
  defp map_stream_name(name), do: name

  @doc false
  def map_nack_action(:park), do: :Park
  def map_nack_action(:retry), do: :Retry
  def map_nack_action(:skip), do: :Skip
  def map_nack_action(:stop), do: :Stop
  def map_nack_action(_), do: :Unknown

  @doc false
  def build_create_request(stream_name, group_name, settings, opts) do
    Persistent.create_req(
      options:
        Persistent.create_req_options(
          stream_identifier: map_create_request_stream_identifier(stream_name),
          stream_option: map_create_stream_option(stream_name, opts),
          group_name: group_name,
          settings: Spear.PersistentSubscription.Settings.to_record(settings, :create)
        )
    )
  end

  @doc false
  def map_short_stream_option(stream_name) when is_binary(stream_name) do
    {:stream_identifier, Shared.stream_identifier(stream_name: stream_name)}
  end

  # coveralls-ignore-start
  def map_short_stream_option(:all) do
    {:all, Shared.empty()}
  end

  # coveralls-ignore-stop

  @doc false
  def map_create_stream_option(stream_name, opts) when is_binary(stream_name) do
    {:stream,
     Persistent.create_req_stream_options(
       stream_identifier: Shared.stream_identifier(stream_name: stream_name),
       revision_option: map_revision(opts)
     )}
  end

  # coveralls-ignore-start
  def map_create_stream_option(:all, opts) do
    from = Keyword.get(opts, :from, :start)

    position =
      with {:position, commit, prepare} <- map_all_position(from) do
        {:position,
         Persistent.create_req_position(commit_position: commit, prepare_position: prepare)}
      end

    {:all,
     Persistent.create_req_all_options(
       all_option: position,
       filter_option: map_filter(Keyword.get(opts, :filter))
     )}
  end

  # coveralls-ignore-stop

  defp map_create_request_stream_identifier(:all), do: :undefined

  defp map_create_request_stream_identifier(stream_name) do
    Shared.stream_identifier(stream_name: stream_name)
  end

  def map_update_stream_option(stream_name, opts) when is_binary(stream_name) do
    {:stream,
     Persistent.update_req_stream_options(
       stream_identifier: Shared.stream_identifier(stream_name: stream_name),
       revision_option: map_revision(opts)
     )}
  end

  # this is roughly the same as the creation options but doesn't include
  # the filter option, just the position option
  def map_update_stream_option(:all, opts) do
    # coveralls-ignore-start
    from = Keyword.get(opts, :from, :start)

    position =
      with {:position, commit, prepare} <- map_all_position(from) do
        {:position,
         Persistent.update_req_position(commit_position: commit, prepare_position: prepare)}
      end

    {:all, Persistent.update_req_all_options(all_option: position)}
    # coveralls-ignore-stop
  end

  # coveralls-ignore-start
  defp map_revision(opts) do
    case Keyword.get(opts, :from, :start) do
      :start -> {:start, Shared.empty()}
      :end -> {:end, Shared.empty()}
      revision when is_integer(revision) -> {:revision, revision}
    end
  end

  defp map_all_position(Persistent.read_resp() = read_resp) do
    read_resp
    |> Spear.Event.from_read_response(link?: true)
    |> map_all_position()
  end

  defp map_all_position(%Spear.Event{link: %Spear.Event{} = link}) do
    map_all_position(link)
  end

  defp map_all_position(%Spear.Event{
         metadata: %{commit_position: commit, prepare_position: prepare}
       }) do
    {:position, commit, prepare}
  end

  defp map_all_position(%Spear.Filter.Checkpoint{
         commit_position: commit,
         prepare_position: prepare
       }) do
    {:position, commit, prepare}
  end

  defp map_all_position(:start), do: {:start, Shared.empty()}
  defp map_all_position(:end), do: {:end, Shared.empty()}

  defp map_filter(%Spear.Filter{} = filter),
    do: {:filter, Spear.Filter._to_persistent_filter_options(filter)}

  defp map_filter(nil), do: {:no_filter, Shared.empty()}

  # coveralls-ignore-stop
end
