defmodule Spear.PersistentSubscription.Info do
  @moduledoc """
  A struct representing information pertaining to a persistent subscription.

  Returned by `Spear.Client.get_persistent_subscription_info/4`
  """
  require Spear.Records.Persistent, as: Persistent

  defmodule ConnectionInfo do
    @moduledoc """
    A struct representing information pertaining to a connection established
    to a `PersistentSubscription`.
    """

    defmodule Measurement do
      @moduledoc """
      A struct representing an observed measurement in a 
      `Spear.PersistentSubscription.Info.ConnectionInfo` structure.
      """

      @typedoc """
      `key` and `value` for an aobserved measurement
      """
      @typedoc since: "1.1.2"
      @type t :: %__MODULE__{
              key: String.t(),
              value: integer()
            }
      defstruct [:key, :value]

      @doc false
      def from_proto(
            Persistent.subscription_info_measurement(
              key: key,
              value: value
            )
          ) do
        %__MODULE__{key: key, value: value}
      end
    end

    alias __MODULE__.Measurement

    @typedoc """
    Information for a connection to a persistent subscription.

    See the EventStoreDB documentation for more information
    """
    @typedoc since: "1.1.2"
    @type t :: %__MODULE__{
            from: String.t(),
            username: String.t(),
            average_items_per_second: integer(),
            total_items: integer(),
            count_since_last_measurement: integer(),
            observed_measurements: list(Measurement.t()),
            available_slots: integer(),
            in_flight_messages: integer(),
            connection_name: String.t()
          }
    defstruct [
      :from,
      :username,
      :average_items_per_second,
      :total_items,
      :count_since_last_measurement,
      :available_slots,
      :in_flight_messages,
      :connection_name,
      observed_measurements: []
    ]

    @doc false
    def from_proto(
          Persistent.subscription_info_connection_info(
            from: from,
            username: username,
            average_items_per_second: average_items_per_second,
            total_items: total_items,
            count_since_last_measurement: count_since_last_measurement,
            observed_measurements: observerd_measurements,
            available_slots: available_slots,
            in_flight_messages: in_flight_messages,
            connection_name: connection_name
          )
        ) do
      %__MODULE__{
        from: from,
        username: username,
        average_items_per_second: average_items_per_second,
        total_items: total_items,
        count_since_last_measurement: count_since_last_measurement,
        observed_measurements: Enum.map(observerd_measurements, &Measurement.from_proto(&1)),
        available_slots: available_slots,
        in_flight_messages: in_flight_messages,
        connection_name: connection_name
      }
    end
  end

  alias __MODULE__.ConnectionInfo
  alias Spear.PersistentSubscription.Settings

  @typedoc """
  details of a persistent subscription.

  See the EventStoredDB for more details.
  """
  @typedoc since: "1.1.2"
  @type t :: %__MODULE__{
          event_source: String.t() | :all,
          group_name: String.t(),
          status: String.t(),
          connections: list(ConnectionInfo.t()),
          average_per_second: integer(),
          total_items: integer(),
          count_since_last_measurement: integer(),
          last_checkpointed_event_position: String.t(),
          last_known_event_position: String.t(),
          resolve_link_tos?: boolean(),
          start_from: String.t(),
          message_timeout_milliseconds: integer(),
          extra_statistics?: boolean(),
          max_retry_count: integer(),
          live_buffer_size: integer(),
          buffer_size: integer(),
          read_batch_size: integer(),
          check_point_after_milliseconds: integer(),
          min_check_point_count: integer(),
          max_check_point_count: integer(),
          read_buffer_count: integer(),
          live_buffer_count: integer(),
          retry_buffer_count: integer(),
          total_in_flight_messages: integer(),
          outstanding_messages_count: integer(),
          named_consumer_strategy: Settings.consumer_strategy(),
          max_subscriber_count: integer(),
          parked_message_count: integer()
        }

  defstruct [
    :event_source,
    :group_name,
    :status,
    :average_per_second,
    :total_items,
    :count_since_last_measurement,
    :last_checkpointed_event_position,
    :last_known_event_position,
    :start_from,
    :message_timeout_milliseconds,
    :max_retry_count,
    :live_buffer_size,
    :buffer_size,
    :read_batch_size,
    :check_point_after_milliseconds,
    :min_check_point_count,
    :max_check_point_count,
    :read_buffer_count,
    :live_buffer_count,
    :retry_buffer_count,
    :total_in_flight_messages,
    :outstanding_messages_count,
    :named_consumer_strategy,
    :max_subscriber_count,
    :parked_message_count,
    connections: [],
    extra_statistics?: false,
    resolve_link_tos?: false
  ]

  @doc false
  def from_proto(
        Persistent.subscription_info(
          event_source: event_source,
          group_name: group_name,
          status: status,
          connections: connections,
          average_per_second: average_per_second,
          total_items: total_items,
          count_since_last_measurement: count_since_last_measurement,
          last_checkpointed_event_position: last_checkpointed_event_position,
          last_known_event_position: last_known_event_position,
          resolve_link_tos: resolve_link_tos,
          start_from: start_from,
          message_timeout_milliseconds: message_timeout_milliseconds,
          extra_statistics: extra_statistics,
          max_retry_count: max_retry_count,
          live_buffer_size: live_buffer_size,
          buffer_size: buffer_size,
          read_batch_size: read_batch_size,
          check_point_after_milliseconds: check_point_after_milliseconds,
          min_check_point_count: min_check_point_count,
          max_check_point_count: max_check_point_count,
          read_buffer_count: read_buffer_count,
          live_buffer_count: live_buffer_count,
          retry_buffer_count: retry_buffer_count,
          total_in_flight_messages: total_in_flight_messages,
          outstanding_messages_count: outstanding_messages_count,
          named_consumer_strategy: named_consumer_strategy,
          max_subscriber_count: max_subscriber_count,
          parked_message_count: parked_message_count
        )
      ) do
    %__MODULE__{
      event_source: map_stream_name(event_source),
      group_name: group_name,
      status: status,
      connections: Enum.map(connections, &ConnectionInfo.from_proto(&1)),
      average_per_second: average_per_second,
      total_items: total_items,
      count_since_last_measurement: count_since_last_measurement,
      last_checkpointed_event_position: last_checkpointed_event_position,
      last_known_event_position: last_known_event_position,
      resolve_link_tos?: resolve_link_tos,
      start_from: start_from,
      message_timeout_milliseconds: message_timeout_milliseconds,
      extra_statistics?: extra_statistics,
      max_retry_count: max_retry_count,
      live_buffer_size: live_buffer_size,
      buffer_size: buffer_size,
      read_batch_size: read_batch_size,
      check_point_after_milliseconds: check_point_after_milliseconds,
      min_check_point_count: min_check_point_count,
      max_check_point_count: max_check_point_count,
      read_buffer_count: read_buffer_count,
      live_buffer_count: live_buffer_count,
      retry_buffer_count: retry_buffer_count,
      total_in_flight_messages: total_in_flight_messages,
      outstanding_messages_count: outstanding_messages_count,
      named_consumer_strategy: from_sub_strategy(named_consumer_strategy),
      max_subscriber_count: max_subscriber_count,
      parked_message_count: parked_message_count
    }
  end

  @doc false
  def build_info_request(stream_name, group_name) do
    require Spear.Records.Persistent

    stream_options =
      Spear.Records.Persistent.get_info_req_options(
        stream_option: Spear.PersistentSubscription.map_short_stream_option(stream_name),
        group_name: group_name
      )

    Spear.Records.Persistent.get_info_req(options: stream_options)
  end

  defp map_stream_name("$all"), do: :all
  defp map_stream_name(name), do: name

  defp from_sub_strategy("RoundRobin"), do: :RoundRobin
  defp from_sub_strategy("Pinned"), do: :Pinned
  defp from_sub_strategy("DispatchToSingle"), do: :DispatchToSingle
end
