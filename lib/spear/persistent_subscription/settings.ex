# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Spear.PersistentSubscription.Settings do
  @moduledoc """
  A struct representing possible settings for a persistent subscription
  """

  @typedoc """
  Possible values for consumer strategies

  The consumer strategy controls how messages are distributed to multiple
  subscribers. The setting has no effect for single-subscriber persistent
  subscriptions.
  """
  @typedoc since: "0.6.0"
  @type consumer_strategy() :: :RoundRobin | :Pinned | :DispatchToSingle

  @typedoc """
  Settings for a persistent subscription

  See the EventStoreDB documentation for more information on each setting.

  The defaults for this struct are set up for a simple case of a single
  subscriber process.

  `:message_timeout` and `:checkpoint_after` may either be specified as
  `{:ticks, ticks}` or any integer where the ticks denote the EventStoreDB
  tick timing. Integers are read as durations in milliseconds.
  """
  @typedoc since: "0.6.0"
  @type t :: %__MODULE__{
          resolve_links?: boolean(),
          revision: non_neg_integer(),
          extra_statistics?: boolean() | nil,
          max_retry_count: non_neg_integer(),
          min_checkpoint_count: pos_integer(),
          max_checkpoint_count: pos_integer(),
          max_subscriber_count: pos_integer(),
          live_buffer_size: pos_integer(),
          read_batch_size: pos_integer(),
          history_buffer_size: pos_integer(),
          named_consumer_strategy: consumer_strategy(),
          message_timeout: {:ticks, pos_integer()} | pos_integer(),
          checkpoint_after: {:ticks, pos_integer()} | pos_integer()
        }

  defstruct resolve_links?: true,
            revision: 0,
            extra_statistics?: false,
            max_retry_count: 10,
            min_checkpoint_count: 1,
            max_checkpoint_count: 100,
            max_subscriber_count: 1,
            live_buffer_size: 100,
            read_batch_size: 100,
            history_buffer_size: 300,
            named_consumer_strategy: :RoundRobin,
            message_timeout: 5_000,
            checkpoint_after: 3_000

  import Spear.Records.Persistent

  @doc false
  def to_record(settings, opration)

  def to_record(%__MODULE__{} = settings, :create) do
    create_req_settings(
      resolve_links: settings.resolve_links?,
      revision: map_revision(settings.revision),
      extra_statistics: settings.extra_statistics?,
      max_retry_count: settings.max_retry_count,
      min_checkpoint_count: settings.min_checkpoint_count,
      max_checkpoint_count: settings.max_checkpoint_count,
      max_subscriber_count: settings.max_subscriber_count,
      live_buffer_size: settings.live_buffer_size,
      read_batch_size: settings.read_batch_size,
      history_buffer_size: settings.history_buffer_size,
      named_consumer_strategy: settings.named_consumer_strategy,
      message_timeout: map_message_timeout(settings.message_timeout),
      checkpoint_after: map_checkpoint_after(settings.checkpoint_after)
    )
  end

  def to_record(%__MODULE__{} = settings, :update) do
    update_req_settings(
      resolve_links: settings.resolve_links?,
      revision: map_revision(settings.revision),
      extra_statistics: settings.extra_statistics?,
      max_retry_count: settings.max_retry_count,
      min_checkpoint_count: settings.min_checkpoint_count,
      max_checkpoint_count: settings.max_checkpoint_count,
      max_subscriber_count: settings.max_subscriber_count,
      live_buffer_size: settings.live_buffer_size,
      read_batch_size: settings.read_batch_size,
      history_buffer_size: settings.history_buffer_size,
      named_consumer_strategy: settings.named_consumer_strategy,
      message_timeout: map_message_timeout(settings.message_timeout),
      checkpoint_after: map_checkpoint_after(settings.checkpoint_after)
    )
  end

  # coveralls-ignore-start
  defp map_message_timeout({:ticks, ticks}), do: {:message_timeout_ticks, ticks}
  defp map_message_timeout(ms) when is_integer(ms), do: {:message_timeout_ms, ms}

  defp map_checkpoint_after({:ticks, ticks}), do: {:checkpoint_after_ticks, ticks}
  defp map_checkpoint_after(ms) when is_integer(ms), do: {:checkpoint_after_ms, ms}

  # coveralls-ignore-stop

  # this option is deprecated, so it's ok to leave it nil (e.g. when we're
  # creating a persistent subscription to the :all stream)
  defp map_revision(revision) when is_integer(revision), do: revision
  defp map_revision(_), do: nil
end
