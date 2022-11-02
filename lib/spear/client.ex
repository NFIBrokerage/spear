# credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity
defmodule Spear.Client do
  @moduledoc """
  A macro for defining a module which represents a connection to an EventStoreDB

  Like an `Ecto.Repo` or an `Extreme` client, this macro allows you to call
  functions on the module representing the connection instead of passing
  the connection pid or name as an argument to functions in `Spear`. This
  can be useful for client connections central to a service. All callbacks
  provided by this module are implemented on clients created with
  `use Spear.Client`.

  This pattern can be useful for applications which depend on an EventStoreDB
  connection similar to applications which depend on a (e.g.) PostgreSQL
  connection via `Ecto.Repo`. Writing clients as modules provides an
  intuitive "is-a" interface (e.g. "`MyEventStoreClient` _is_ an EventStoreDB
  client"). Since this module defines a complete behaviour for a client
  module, mocking calls to the EventStoreDB is easy via a test dependency
  like the wonderful Dashbit library [`Mox`](https://github.com/dashbitco/mox).

  If a service does not know which connections it may need until runtime, the
  functions in Spear may be used with a connection processes spawned via
  `DynamicSupervisor.start_child/2` instead.

  ## Configuration

  The `__using__/1` macro defined by this module takes an optional `:otp_app`
  option. If provided, a helper clause for the `c:start_link/1` callback will
  be injected which will fetch configuration for the connection from
  `Application.get_env(otp_app, __MODULE__)`, if available.

  Otherwise configuration for the connection may be passed through arguments
  to `c:start_link/1`.

  ## Examples

      defmodule MyEventStoreClient do
        use Spear.Client, otp_app: :my_app
      end

      [MyEventStoreClient] |> Supervisor.start_link(strategy: :one_for_one)

      iex> MyEventStoreClient.stream!(:all) |> Enum.take(1)
      [%Spear.Event{}]
  """

  @doc """
  Starts a client as part of a supervision tree.

  This function is defaulted to pull connection parameters from application
  config or from the `args`

  ## Examples

      # lib/my_app/application.ex
      [
        {MyEventStoreClient, connection_string: "esdb://localhost:2113"},
        ..
      ]
      |> Supervisor.start_link(strategy: :one_for_one)
  """
  @doc since: "0.1.0"
  @callback start_link(args :: Keyword.t()) :: GenServer.on_start()

  @doc """
  A wrapper around `Spear.append/3`
  """
  @doc since: "0.1.0"
  @callback append(event_stream :: Enumerable.t(), stream_name :: String.t()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.append/4`
  """
  @doc since: "0.1.0"
  @callback append(event_stream :: Enumerable.t(), stream_name :: String.t(), opts :: Keyword.t()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.append_batch/4`
  """
  @doc since: "0.10.0"
  @callback append_batch(
              event_stream :: Enumerable.t(),
              request_id :: reference() | :new,
              stream_name :: String.t()
            ) ::
              :ok | {:error, any()} | tuple()

  @doc """
  A wrapper around `Spear.append_batch/5`
  """
  @doc since: "0.10.0"
  @callback append_batch(
              event_stream :: Enumerable.t(),
              request_id :: reference() | :new,
              stream_name :: String.t(),
              opts :: Keyword.t()
            ) ::
              :ok | {:error, any()} | tuple()

  @doc """
  A wrapper around `Spear.append_batch_stream/2`
  """
  @doc since: "0.10.0"
  @callback append_batch_stream(batch_stream :: Enumerable.t()) :: Enumerable.t()

  @doc """
  A wrapper around `Spear.cancel_subscription/2`
  """
  @doc since: "0.1.0"
  @callback cancel_subscription(subscription_reference :: reference()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.cancel_subscription/3`
  """
  @doc since: "0.1.0"
  @callback cancel_subscription(subscription_reference :: reference(), timeout()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_stream/2`
  """
  @doc since: "0.1.0"
  @callback delete_stream(stream_name :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_stream/3`
  """
  @doc since: "0.1.0"
  @callback delete_stream(stream_name :: String.t(), opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.read_stream/2`
  """
  @doc since: "0.1.0"
  @callback read_stream(stream_name :: String.t() | :all) ::
              {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.read_stream/3`
  """
  @doc since: "0.1.0"
  @callback read_stream(stream_name :: String.t() | :all, opts :: Keyword.t()) ::
              {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.stream!/2`
  """
  @doc since: "0.1.0"
  @callback stream!(stream_name :: String.t() | :all) :: Enumerable.t()

  @doc """
  A wrapper around `Spear.stream!/3`
  """
  @doc since: "0.1.0"
  @callback stream!(stream_name :: String.t() | :all, opts :: Keyword.t()) :: Enumerable.t()

  @doc """
  A wrapper around `Spear.subscribe/3`
  """
  @doc since: "0.1.0"
  @callback subscribe(subscriber :: pid() | GenServer.name(), stream_name :: String.t() | :all) ::
              {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.ping/1`
  """
  @doc since: "0.1.2"
  @callback ping() :: :pong | {:error, any()}

  @doc """
  A wrapper around `Spear.ping/2`
  """
  @doc since: "0.1.2"
  @callback ping(timeout()) :: :pong | {:error, any()}

  @doc """
  A wrapper around `Spear.subscribe/4`
  """
  @doc since: "0.1.0"
  @callback subscribe(
              subscriber :: pid() | GenServer.name(),
              stream_name :: String.t() | :all,
              opts :: Keyword.t()
            ) :: {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.set_global_acl/3`
  """
  @doc since: "0.1.0"
  @callback set_global_acl(
              user_acl :: Spear.Acl.t(),
              system_acl :: Spear.Acl.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.set_global_acl/4`
  """
  @doc since: "0.1.0"
  @callback set_global_acl(
              user_acl :: Spear.Acl.t(),
              system_acl :: Spear.Acl.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.set_stream_metadata/3`
  """
  @doc since: "0.2.1"
  @callback set_stream_metadata(
              stream :: String.t(),
              metadata :: Spear.StreamMetadata.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.set_stream_metadata/4`
  """
  @doc since: "0.2.1"
  @callback set_stream_metadata(
              stream :: String.t(),
              metadata :: Spear.StreamMetadata.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.get_stream_metadata/2`
  """
  @doc since: "0.2.1"
  @callback get_stream_metadata(stream :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.get_stream_metadata/3`
  """
  @doc since: "0.2.1"
  @callback get_stream_metadata(
              stream :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.change_user_password/4`
  """
  @doc since: "0.3.0"
  @callback change_user_password(
              login_name :: String.t(),
              current_password :: String.t(),
              new_password :: String.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.change_user_password/5`
  """
  @doc since: "0.3.0"
  @callback change_user_password(
              login_name :: String.t(),
              current_password :: String.t(),
              new_password :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.create_user/5`
  """
  @doc since: "0.3.0"
  @callback create_user(
              full_name :: String.t(),
              login_name :: String.t(),
              password :: String.t(),
              groups :: [String.t()]
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.create_user/6`
  """
  @doc since: "0.3.0"
  @callback create_user(
              full_name :: String.t(),
              login_name :: String.t(),
              password :: String.t(),
              groups :: [String.t()],
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_user/2`
  """
  @doc since: "0.3.0"
  @callback delete_user(login_name :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_user/3`
  """
  @doc since: "0.3.0"
  @callback delete_user(
              login_name :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.disable_user/2`
  """
  @doc since: "0.3.0"
  @callback disable_user(login_name :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.disable_user/3`
  """
  @doc since: "0.3.0"
  @callback disable_user(
              login_name :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.enable_user/2`
  """
  @doc since: "0.3.0"
  @callback enable_user(login_name :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.enable_user/3`
  """
  @doc since: "0.3.0"
  @callback enable_user(
              login_name :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.reset_user_password/3`
  """
  @doc since: "0.3.0"
  @callback reset_user_password(
              login_name :: String.t(),
              new_password :: String.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.reset_user_password/4`
  """
  @doc since: "0.3.0"
  @callback reset_user_password(
              login_name :: String.t(),
              new_password :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.update_user/5`
  """
  @doc since: "0.3.0"
  @callback update_user(
              full_name :: String.t(),
              login_name :: String.t(),
              password :: String.t(),
              groups :: [String.t()]
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.update_user/6`
  """
  @doc since: "0.3.0"
  @callback update_user(
              full_name :: String.t(),
              login_name :: String.t(),
              password :: String.t(),
              groups :: [String.t()],
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.user_details/3`
  """
  @doc since: "0.3.0"
  @callback user_details(login_name :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.user_details/3`
  """
  @doc since: "0.3.0"
  @callback user_details(
              login_name :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.merge_indexes/1`
  """
  @doc since: "0.4.0"
  @callback merge_indexes() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.merge_indexes/2`
  """
  @doc since: "0.4.0"
  @callback merge_indexes(opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.resign_node/1`
  """
  @doc since: "0.4.0"
  @callback resign_node() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.resign_node/2`
  """
  @doc since: "0.4.0"
  @callback resign_node(opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.restart_persistent_subscriptions/1`
  """
  @doc since: "0.4.0"
  @callback restart_persistent_subscriptions() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.restart_persistent_subscriptions/2`
  """
  @doc since: "0.4.0"
  @callback restart_persistent_subscriptions(opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.set_node_priority/2`
  """
  @doc since: "0.4.0"
  @callback set_node_priority(priority :: integer()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.set_node_priority/3`
  """
  @doc since: "0.4.0"
  @callback set_node_priority(
              priority :: integer(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.shutdown/1`
  """
  @doc since: "0.4.0"
  @callback shutdown() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.shutdown/2`
  """
  @doc since: "0.4.0"
  @callback shutdown(opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.start_scavenge/1`
  """
  @doc since: "0.4.0"
  @callback start_scavenge() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.start_scavenge/2`
  """
  @doc since: "0.4.0"
  @callback start_scavenge(opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.stop_scavenge/2`
  """
  @doc since: "0.4.0"
  @callback stop_scavenge(scavenge_id :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.stop_scavenge/3`
  """
  @doc since: "0.4.0"
  @callback stop_scavenge(
              scavenge_id :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.cluster_info/1`
  """
  @doc since: "0.5.0"
  @callback cluster_info() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.cluster_info/2`
  """
  @doc since: "0.5.0"
  @callback cluster_info(opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.create_persistent_subscription/4`
  """
  @doc since: "0.6.0"
  @callback create_persistent_subscription(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              settings :: Spear.PersistentSubscription.Settings.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.create_persistent_subscription/5`
  """
  @doc since: "0.6.0"
  @callback create_persistent_subscription(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              settings :: Spear.PersistentSubscription.Settings.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.get_persistent_subscription_info/3`
  """
  @doc since: "1.2.0"
  @callback get_persistent_subscription_info(
              stream_name :: String.t() | :all,
              group_name :: String.t()
            ) :: {:ok, Spear.PersistentSubscription.Info.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.get_persistent_subscription_info/4`
  """
  @doc since: "1.2.0"
  @callback get_persistent_subscription_info(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              opts :: Keyword.t()
            ) :: {:ok, Spear.PersistentSubscription.Info.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.update_persistent_subscription/4`
  """
  @doc since: "0.6.0"
  @callback update_persistent_subscription(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              settings :: Spear.PersistentSubscription.Settings.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.update_persistent_subscription/5`
  """
  @doc since: "0.6.0"
  @callback update_persistent_subscription(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              settings :: Spear.PersistentSubscription.Settings.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_persistent_subscription/3`
  """
  @doc since: "0.6.0"
  @callback delete_persistent_subscription(
              stream_name :: String.t() | :all,
              group_name :: String.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_persistent_subscription/4`
  """
  @doc since: "0.6.0"
  @callback delete_persistent_subscription(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.list_persistent_subscriptions/1`
  """
  @doc since: "0.6.0"
  @callback list_persistent_subscriptions() :: {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.list_persistent_subscriptions/2`
  """
  @doc since: "0.6.0"
  @callback list_persistent_subscriptions(opts :: Keyword.t()) ::
              {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.connect_to_persistent_subscription/4`
  """
  @doc since: "0.6.0"
  @callback connect_to_persistent_subscription(
              subscriber :: pid() | GenServer.name(),
              stream_name :: String.t() | :all,
              group_name :: String.t()
            ) :: {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.connect_to_persistent_subscription/5`
  """
  @doc since: "0.6.0"
  @callback connect_to_persistent_subscription(
              subscriber :: pid() | GenServer.name(),
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              opts :: Keyword.t()
            ) :: {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.ack/3`
  """
  @doc since: "0.6.0"
  @callback ack(
              subscription :: reference(),
              event_or_ids :: Spear.Event.t() | [String.t()]
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.nack/3`
  """
  @doc since: "0.6.0"
  @callback nack(
              subscription :: reference(),
              event_or_ids :: Spear.Event.t() | [String.t()]
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.nack/4`
  """
  @doc since: "0.6.0"
  @callback nack(
              subscription :: reference(),
              event_or_ids :: Spear.Event.t() | [String.t()],
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.replay_parked_messages/3`
  """
  @doc since: "1.2.0"
  @callback replay_parked_messages(stream_name :: String.t() | :all, group_name :: String.t()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.replay_parked_messages/4`
  """
  @doc since: "1.2.0"
  @callback replay_parked_messages(
              stream_name :: String.t() | :all,
              group_name :: String.t(),
              opts :: Keyword.t()
            ) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.restart_persistent_subscription_subsystem/1`
  """
  @doc since: "1.2.0"
  @callback restart_persistent_subscription_subsystem() :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.restart_persistent_subscription_subsystem/2`
  """
  @doc since: "1.2.0"
  @callback restart_persistent_subscription_subsystem(opts :: Keyword.t()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.subscribe_to_stats/2`
  """
  @doc since: "0.10.0"
  @callback subscribe_to_stats(subscriber :: pid() | GenServer.name()) ::
              {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.subscribe_to_stats/3`
  """
  @doc since: "0.10.0"
  @callback subscribe_to_stats(
              subscriber :: pid() | GenServer.name(),
              opts :: Keyword.t()
            ) :: {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.get_supported_rpcs/1`
  """
  @doc since: "0.11.0"
  @callback get_supported_rpcs() :: {:ok, [Spear.SupportedRpc.t()]} | {:error, any()}

  @doc """
  A wrapper around `Spear.get_supported_rpcs/2`
  """
  @doc since: "0.11.0"
  @callback get_supported_rpcs(Keyword.t()) :: {:ok, [Spear.SupportedRpc.t()]} | {:error, any()}

  @doc """
  A wrapper around `Spear.get_server_version/1`
  """
  @doc since: "0.11.0"
  @callback get_server_version() :: {:ok, String.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.get_server_version/2`
  """
  @doc since: "0.11.0"
  @callback get_server_version(Keyword.t()) :: {:ok, String.t()} | {:error, any()}

  @optional_callbacks start_link: 1

  defmacro __using__(opts) when is_list(opts) do
    quote do
      @behaviour unquote(__MODULE__)

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]}
        }
      end

      @impl unquote(__MODULE__)
      unquote(start_link_helper(opts))
      defoverridable start_link: 1

      @impl unquote(__MODULE__)
      def append(event_stream, stream_name, opts \\ []) do
        Spear.append(event_stream, __MODULE__, stream_name, opts)
      end

      @impl unquote(__MODULE__)
      def append_batch(event_stream, request_id, stream_name, opts \\ []) do
        Spear.append_batch(event_stream, __MODULE__, request_id, stream_name, opts)
      end

      @impl unquote(__MODULE__)
      def append_batch_stream(batch_stream) do
        Spear.append_batch_stream(batch_stream, __MODULE__)
      end

      @impl unquote(__MODULE__)
      def cancel_subscription(subscription_reference, timeout \\ 5_000) do
        Spear.cancel_subscription(__MODULE__, subscription_reference, timeout)
      end

      @impl unquote(__MODULE__)
      def delete_stream(stream_name, opts \\ []) do
        Spear.delete_stream(__MODULE__, stream_name, opts)
      end

      @impl unquote(__MODULE__)
      def read_stream(stream_name, opts \\ []) do
        Spear.read_stream(__MODULE__, stream_name, opts)
      end

      @impl unquote(__MODULE__)
      def stream!(stream_name, opts \\ []) do
        Spear.stream!(__MODULE__, stream_name, opts)
      end

      @impl unquote(__MODULE__)
      def subscribe(subscriber, stream_name, opts \\ []) do
        Spear.subscribe(__MODULE__, subscriber, stream_name, opts)
      end

      @impl unquote(__MODULE__)
      def ping(timeout \\ 5_000) do
        Spear.ping(__MODULE__, timeout)
      end

      @impl unquote(__MODULE__)
      def set_global_acl(user_acl, system_acl, opts \\ []) do
        Spear.set_global_acl(__MODULE__, user_acl, system_acl, opts)
      end

      @impl unquote(__MODULE__)
      def set_stream_metadata(stream, metadata, opts \\ []) do
        Spear.set_stream_metadata(__MODULE__, stream, metadata, opts)
      end

      @impl unquote(__MODULE__)
      def get_stream_metadata(stream, opts \\ []) do
        Spear.get_stream_metadata(__MODULE__, stream, opts)
      end

      @impl unquote(__MODULE__)
      def change_user_password(login_name, current_password, new_password, opts \\ []) do
        Spear.change_user_password(__MODULE__, login_name, current_password, new_password, opts)
      end

      @impl unquote(__MODULE__)
      def create_user(full_name, login_name, password, groups, opts \\ []) do
        Spear.create_user(__MODULE__, full_name, login_name, password, groups, opts)
      end

      @impl unquote(__MODULE__)
      def delete_user(login_name, opts \\ []) do
        Spear.delete_user(__MODULE__, login_name, opts)
      end

      @impl unquote(__MODULE__)
      def disable_user(login_name, opts \\ []) do
        Spear.disable_user(__MODULE__, login_name, opts)
      end

      @impl unquote(__MODULE__)
      def enable_user(login_name, opts \\ []) do
        Spear.enable_user(__MODULE__, login_name, opts)
      end

      @impl unquote(__MODULE__)
      def reset_user_password(login_name, new_password, opts \\ []) do
        Spear.reset_user_password(__MODULE__, login_name, new_password, opts)
      end

      @impl unquote(__MODULE__)
      def update_user(full_name, login_name, password, groups, opts \\ []) do
        Spear.update_user(__MODULE__, full_name, login_name, password, groups, opts)
      end

      @impl unquote(__MODULE__)
      def user_details(login_name, opts \\ []) do
        Spear.user_details(__MODULE__, login_name, opts)
      end

      @impl unquote(__MODULE__)
      def merge_indexes(opts \\ []) do
        Spear.merge_indexes(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def resign_node(opts \\ []) do
        Spear.resign_node(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def restart_persistent_subscriptions(opts \\ []) do
        Spear.restart_persistent_subscriptions(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def set_node_priority(priority, opts \\ []) when is_integer(priority) do
        Spear.set_node_priority(__MODULE__, priority, opts)
      end

      @impl unquote(__MODULE__)
      def shutdown(opts \\ []) do
        Spear.shutdown(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def start_scavenge(opts \\ []) do
        Spear.start_scavenge(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def stop_scavenge(scavenge_id, opts \\ []) do
        Spear.stop_scavenge(__MODULE__, scavenge_id, opts)
      end

      @impl unquote(__MODULE__)
      def cluster_info(opts \\ []) do
        Spear.cluster_info(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def create_persistent_subscription(stream_name, group_name, settings, opts \\ []) do
        Spear.create_persistent_subscription(__MODULE__, stream_name, group_name, settings, opts)
      end

      @impl unquote(__MODULE__)
      def get_persistent_subscription_info(stream_name, group_name, opts \\ []) do
        Spear.get_persistent_subscription_info(__MODULE__, stream_name, group_name, opts)
      end

      @impl unquote(__MODULE__)
      def update_persistent_subscription(stream_name, group_name, settings, opts \\ []) do
        Spear.update_persistent_subscription(__MODULE__, stream_name, group_name, settings, opts)
      end

      @impl unquote(__MODULE__)
      def delete_persistent_subscription(stream_name, group_name, opts \\ []) do
        Spear.delete_persistent_subscription(__MODULE__, stream_name, group_name, opts)
      end

      @impl unquote(__MODULE__)
      def list_persistent_subscriptions(opts \\ []) do
        Spear.list_persistent_subscriptions(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def connect_to_persistent_subscription(subscriber, stream_name, group_name, opts \\ []) do
        Spear.connect_to_persistent_subscription(
          __MODULE__,
          subscriber,
          stream_name,
          group_name,
          opts
        )
      end

      @impl unquote(__MODULE__)
      def ack(subscription, event_or_ids) do
        Spear.ack(__MODULE__, subscription, event_or_ids)
      end

      @impl unquote(__MODULE__)
      def nack(subscription, event_or_ids, opts \\ []) do
        Spear.nack(__MODULE__, subscription, event_or_ids, opts)
      end

      @impl unquote(__MODULE__)
      def replay_parked_messages(stream_name, group_name, opts \\ []) do
        Spear.replay_parked_messages(__MODULE__, stream_name, group_name, opts)
      end

      @impl unquote(__MODULE__)
      def restart_persistent_subscription_subsystem(opts \\ []) do
        Spear.restart_persistent_subscription_subsystem(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def subscribe_to_stats(subscriber, opts \\ []) do
        Spear.subscribe_to_stats(__MODULE__, subscriber, opts)
      end

      @impl unquote(__MODULE__)
      def get_supported_rpcs(opts \\ []) do
        Spear.get_supported_rpcs(__MODULE__, opts)
      end

      @impl unquote(__MODULE__)
      def get_server_version(opts \\ []) do
        Spear.get_server_version(__MODULE__, opts)
      end
    end
  end

  defp start_link_helper(opts) do
    case Keyword.fetch(opts, :otp_app) do
      {:ok, otp_app} ->
        quote do
          def start_link(args) do
            Application.get_env(unquote(otp_app), __MODULE__)
            |> Keyword.merge(args)
            |> Keyword.put(:name, __MODULE__)
            |> Spear.Connection.start_link()
          end
        end

      :error ->
        quote do
          def start_link(args) do
            args
            |> Keyword.put(:name, __MODULE__)
            |> Spear.Connection.start_link()
          end
        end
    end
  end
end
