defmodule Spear.Client do
  @moduledoc """
  A macro for defining a module which represents a connection to an EventStore

  Like an `Ecto.Repo` or an `Extreme` client, this macro allows you to call
  functions on the module representing the connection instead of passing
  the connection pid or name as an argument to functions in `Spear`. This
  can be useful for client connections central to a service. All callbacks
  provided by this module are implemented on clients created with
  `use Spear.Client`.

  This pattern can be useful for applications which depend on an EventStore
  connection similar to applications which depend on a (e.g.) PostgreSQL
  connection via `Ecto.Repo`. Writing clients as modules provides an
  intuitive "is-a" interface (e.g. "`MyEventStoreClient` _is_ an EventStore
  client"). Since this module defines a complete behaviour for a client
  module, mocking calls to the EventStore is easy via a test dependency
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
  @callback start_link(args :: Keyword.t()) :: GenServer.on_start()

  @doc """
  A wrapper around `Spear.append/3`
  """
  @callback append(event_stream :: Enumerable.t(), stream_name :: String.t()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.append/4`
  """
  @callback append(event_stream :: Enumerable.t(), stream_name :: String.t(), opts :: Keyword.t()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.cancel_subscription/2`
  """
  @callback cancel_subscription(subscription_reference :: reference()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.cancel_subscription/3`
  """
  @callback cancel_subscription(subscription_reference :: reference(), timeout()) ::
              :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_stream/2`
  """
  @callback delete_stream(stream_name :: String.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.delete_stream/3`
  """
  @callback delete_stream(stream_name :: String.t(), opts :: Keyword.t()) :: :ok | {:error, any()}

  @doc """
  A wrapper around `Spear.read_stream/2`
  """
  @callback read_stream(stream_name :: String.t() | :all) ::
              {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.read_stream/3`
  """
  @callback read_stream(stream_name :: String.t() | :all, opts :: Keyword.t()) ::
              {:ok, Enumerable.t()} | {:error, any()}

  @doc """
  A wrapper around `Spear.stream!/2`
  """
  @callback stream!(stream_name :: String.t() | :all) :: Enumerable.t()

  @doc """
  A wrapper around `Spear.stream!/3`
  """
  @callback stream!(stream_name :: String.t() | :all, opts :: Keyword.t()) :: Enumerable.t()

  @doc """
  A wrapper around `Spear.subscribe/3`
  """
  @callback subscribe(subscriber :: pid() | GenServer.name(), stream_name :: String.t() | :all) ::
              {:ok, reference()} | {:error, any()}

  @doc """
  A wrapper around `Spear.subscribe/4`
  """
  @callback subscribe(
              subscriber :: pid() | GenServer.name(),
              stream_name :: String.t() | :all,
              opts :: Keyword.t()
            ) :: {:ok, reference()} | {:error, any()}

  @optional_callbacks start_link: 1

  defmacro __using__(opts) when is_list(opts) do
    quote do
      @behaviour unquote(__MODULE__)

      @impl unquote(__MODULE__)
      unquote(start_link_helper(opts))
      defoverridable start_link: 1

      @impl unquote(__MODULE__)
      def append(event_stream, stream_name, opts \\ []) do
        Spear.append(event_stream, __MODULE__, stream_name, opts)
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
      def subscribe(subscriber, stream_name, opts) do
        Spear.subscribe(__MODULE__, subscriber, stream_name, opts)
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
