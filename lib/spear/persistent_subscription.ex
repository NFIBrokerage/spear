defmodule Spear.PersistentSubscription do
  @moduledoc """
  A struct representing a persistent subscription and its settings
  """

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
      stream_name: map["stream"],
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
end
