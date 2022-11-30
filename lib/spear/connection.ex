defmodule Spear.Connection do
  @moduledoc """
  A GenServer which brokers a connection to an EventStoreDB

  `Spear.Connection` will attempt to connect immediately after GenServer init.
  Failures to connect will result in back-off retries in segments of 500ms.
  Any GenServer to a connection process may return `{:error, :closed}` if the
  connection process is alive but the HTTP2 connection to the EventStoreDB
  is not yet (re)established. `Spear.Connection` will automatically attempt
  to re-connect to the EventStoreDB if the connection is severed.

  `Spear.Connection` processes accept `GenServer.call/3`s of `:close` to
  force a disconnect from an EventStoreDB and a subsequent `GenServer.cast/2`
  of `:connect` to reconnect based on the configuration supplied at init-time.

  If configuration parameters must change between disconnects and reconnects,
  spawning and killing connections with a `DynamicSupervisor` is recommended.

  ## Configuration

  See the `Spear.Connection.Configuration` module for available configuration
  of connections.

  ## TLS/SSL configuration and credentials

  See the [Security guide](guides/security.md) for information about
  certificates, credentials, and access control lists (ACLs).

  ## Keep-alive

  Spear and the EventStoreDB use gRPC keep-alive to ensure that any hung
  connections are noticed and restarted.

  EventStoreDB has its own configuration for keep-alive and each Spear
  client's configuration should not necessarily match the server configuration.
  With a `:keep_alive_interval` too low on the Spear-side and with very many
  connected clients, the keep-alive pings can effectively become a DDoS
  even while no clients perform any operations. This does not necessarily
  apply to the keep-alive settings in EventStoreDB: a client connects to a
  single EventStoreDB but an EventStoreDB may have hundreds or more clients
  connected at once.

  `:keep_alive_interval` does not express an interval in the way of
  `:timer.send_interval/3`. Instead the keep-alive timer is optimized to
  reset upon any data received from the connection.

  This means that (assuming consistent network, which is generous) either the
  Spear client or EventStoreDB server will dominate the keep-alive ping
  communication, the driver of the conversation being which ever has the
  lowest keep-alive interval configured. For this reason, it is generally
  advisable to set the client keep-alive just higher than the server
  keep-alive, adding noise for network latency, since the client's keep-alive
  routine will only trigger when the server's keep-alive message is behind
  schedule.

  Note that there may not be much value in attempting to optimize the
  keep-alive settings unless the network is very unstable: keep-alive only
  has utility when the client, server, or network is seriously delayed or
  silently severed.

  ## Examples

      iex> {:ok, conn} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")
      iex> Spear.stream!(conn, "es_supported_clients") |> Enum.take(3)
      [%Spear.Event{}, %Spear.Event{}, %Spear.Event{}]
  """

  # see the very similar original implementation of this process architecture
  # from the Mint documentation:
  # https://github.com/elixir-mint/mint/blob/796b8db097d69ede7163acba223ab2045c2773a4/pages/Architecture.md

  use Connection
  require Logger

  alias Spear.Connection.{Request, KeepAliveTimer}
  alias Spear.Connection.Configuration, as: Config

  @post "POST"
  @closed %Mint.TransportError{reason: :closed}
  @read_apis %{
    Spear.Records.Streams => [:Read],
    Spear.Records.Gossip => [:Read],
    Spear.Records.Persistent => [:Read],
    Spear.Records.Projections => [:Statistics, :State, :Result],
    Spear.Records.Users => [:Details],
    Spear.Records.Operations => []
  }

  defstruct [:config, :conn, requests: %{}, keep_alive_timer: %KeepAliveTimer{}]

  @typedoc """
  A connection process

  A connection process (either referred to as `conn` or `connection` in the
  documentation) may either be a PID or a name such as a module or otherwise
  atom.

  ## Examples


      iex> {:ok, conn} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")
      {:ok, #PID<0.225.0>}
      iex> Spear.read_stream(conn, "es_supported_clients", max_count: 1)
      {:ok,
       #Stream<[
         enum: #Function<62.80860365/2 in Stream.unfold/2>,
         funs: [#Function<48.80860365/1 in Stream.map/2>]
       ]>}
  """
  @typedoc since: "0.1.0"
  @type t :: pid() | GenServer.name()

  @doc false
  def child_spec(init_arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [init_arg]}
    }
  end

  @doc """
  Starts a connection process

  This function can be called directly in order to link it to the current
  process, but the more common workflow is to start a `Spear.Connection`
  GenServer as a part of a supervision tree.

  ## Examples

  E.g. in an application's supervision tree defined in
  `lib/my_app/application.ex`:

      children = [
        {Spear.Connection, name: MyConnection, connection_string: "esdb://localhost:2113"}
      ]
      Supervisor.start_link(children, strategy: :one_for_one)
  """
  @typedoc since: "0.1.0"
  @spec start_link(opts :: Keyword.t()) :: {:ok, t()} | GenServer.on_start()
  def start_link(opts) do
    name = Keyword.take(opts, [:name])
    rest = Keyword.delete(opts, :name)

    Connection.start_link(__MODULE__, rest, name)
  end

  @impl Connection
  def init(opts) do
    case Config.new(opts) do
      %Config{valid?: true} = config ->
        {:connect, :init, %__MODULE__{config: config}}

      %Config{errors: errors} ->
        error_lines =
          errors
          |> Enum.map(fn {key, error} -> "\t#{inspect(key)}: #{error}" end)
          |> Enum.join("\n")

        Logger.error("""
        Invalid configuration passed to #{inspect(__MODULE__)}. Found the following errors:

        #{error_lines}
        """)

        :ignore
    end
  end

  @impl Connection
  def connect(_, s) do
    case do_connect(s.config) do
      {:ok, conn} ->
        case s.config.register_with do
          %{registry: reg, key: k, value: _} ->
            Registry.register(reg, k, Map.get(s.config.register_with, :value, nil))

          _ ->
            nil
        end

        {:ok, %__MODULE__{s | conn: conn, keep_alive_timer: KeepAliveTimer.start(s.config)}}

      {:error, _reason} ->
        {:backoff, 500, s}
    end
  end

  @impl Connection
  def disconnect(info, %__MODULE__{conn: conn} = s) do
    {:ok, _conn} = Mint.HTTP.close(conn)

    :ok = close_requests(s)

    s = %__MODULE__{
      s
      | conn: nil,
        requests: %{},
        keep_alive_timer: KeepAliveTimer.clear(s.keep_alive_timer)
    }

    case s.config.register_with do
      %{registry: reg, key: k, value: _} ->
        Registry.unregister(reg, k)

      _ ->
        nil
    end

    case info do
      {:close, from} ->
        Connection.reply(from, {:ok, :closed})

        {:noconnect, s}

      _ ->
        {:connect, :reconnect, s}
    end
  end

  @impl Connection
  def handle_cast(:connect, s), do: {:connect, s.config, s}

  def handle_cast({:push, request_ref, message}, s) when is_reference(request_ref) do
    # YARD backpressure and http2 window sizes
    with %{rpc: rpc} <- s.requests[request_ref],
         {wire_data, _size} =
           Spear.Request.to_wire_data(message, rpc.service_module, rpc.request_type),
         {:ok, conn} <- Mint.HTTP2.stream_request_body(s.conn, request_ref, wire_data) do
      {:noreply, put_in(s.conn, conn)}
    else
      # coveralls-ignore-start
      nil ->
        {:noreply, s}

      {:error, conn, reason} ->
        s = put_in(s.conn, conn)

        if reason == @closed, do: {:disconnect, :closed, s}, else: {:noreply, s}
        # coveralls-ignore-stop
    end
  end

  @impl Connection
  def handle_call(_call, _from, %__MODULE__{conn: nil} = s) do
    {:reply, {:error, :closed}, s}
  end

  def handle_call(:close, from, s), do: {:disconnect, {:close, from}, s}

  def handle_call(:ping, from, s) do
    case Mint.HTTP2.ping(s.conn) do
      {:ok, conn, request_ref} ->
        s = put_in(s.conn, conn)
        s = put_in(s.requests[request_ref], {:ping, from})
        # put request ref
        {:noreply, s}

      # coveralls-ignore-start
      {:error, conn, @closed} ->
        {:disconnect, :closed, {:error, :closed}, put_in(s.conn, conn)}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(s.conn, conn)}
        # coveralls-ignore-stop
    end
  end

  def handle_call({:cancel, request_ref}, _from, s) when is_reference(request_ref) do
    with true <- Map.has_key?(s.requests, request_ref),
         {:ok, conn} <- Mint.HTTP2.cancel_request(s.conn, request_ref) do
      {:reply, :ok, put_in(s.conn, conn)}
    else
      # coveralls-ignore-start
      false ->
        # idempotent success when the request_ref is not active
        {:reply, :ok, s}

      {:error, conn, @closed} ->
        {:disconnect, :closed, {:error, :closed}, put_in(s.conn, conn)}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(s.conn, conn)}
        # coveralls-ignore-stop
    end
  end

  def handle_call({type, request}, from, s) do
    request = Spear.Request.merge_credentials(request, Config.credentials(s.config))

    with :ok <- read_only_check(request, s),
         {:ok, s} <- request_and_stream_body(s, request, from, type) do
      {:noreply, s}
    else
      {:error, :read_only} ->
        {:reply, {:error, :read_only}, s}

      # coveralls-ignore-start
      {:error, s, @closed} ->
        {:disconnect, :closed, {:error, :closed}, s}

      {:error, s, reason} ->
        {:reply, {:error, reason}, s}
        # coveralls-ignore-stop
    end
  end

  @impl Connection
  def handle_info({:DOWN, monitor_ref, :process, _object, _reason}, s) do
    with {:ok, %{request_ref: request_ref} = request} <-
           fetch_subscription(s, monitor_ref),
         {^request, s} <- pop_in(s.requests[request_ref]),
         {:ok, conn} <- Mint.HTTP2.cancel_request(s.conn, request_ref) do
      {:noreply, put_in(s.conn, conn)}
    else
      # coveralls-ignore-start
      {:error, conn, reason} ->
        s = put_in(s.conn, conn)

        if reason == @closed, do: {:disconnect, :closed, s}, else: {:noreply, s}

      _ ->
        {:noreply, s}
        # coveralls-ignore-stop
    end
  end

  def handle_info(:keep_alive, s) do
    case Mint.HTTP2.ping(s.conn) do
      {:ok, conn, request_ref} ->
        s = put_in(s.conn, conn)
        s = update_in(s.keep_alive_timer, &KeepAliveTimer.start_timeout_timer(&1, request_ref))

        {:noreply, s}

      # coveralls-ignore-start
      {:error, conn, reason} ->
        s = put_in(s.conn, conn)

        if reason == @closed, do: {:disconnect, :closed, s}, else: {:noreply, s}
        # coveralls-ignore-stop
    end
  end

  def handle_info(:keep_alive_expired, s), do: {:disconnect, :keep_alive_timeout, s}

  def handle_info(message, s) do
    with %Mint.HTTP2{} = conn <- s.conn,
         {:ok, conn, responses} <- Mint.HTTP2.stream(conn, message) do
      {:noreply, put_in(s.conn, conn) |> handle_responses(responses)}
    else
      # coveralls-ignore-start
      {:error, conn, reason, responses} ->
        s = put_in(s.conn, conn) |> handle_responses(responses)

        # YARD error handling
        if reason == @closed, do: {:disconnect, :closed, s}, else: {:noreply, s}

      # coveralls-ignore-stop

      # unknown message / no active conn in state
      _ ->
        {:noreply, s}
    end
  end

  @spec handle_responses(%__MODULE__{}, list()) :: %__MODULE__{}
  defp handle_responses(s, responses) do
    s = update_in(s.keep_alive_timer, &KeepAliveTimer.reset_interval_timer/1)

    responses
    |> Enum.reduce(s, &process_response/2)
    |> Request.continue_requests()
  end

  defp process_response({:status, request_ref, status}, s) do
    put_in(s.requests[request_ref].response.status, status)
  end

  defp process_response({:headers, request_ref, new_headers}, s) do
    update_in(
      s.requests[request_ref].response.headers,
      fn headers -> headers ++ new_headers end
    )
  end

  defp process_response({:data, request_ref, new_data}, s) do
    update_in(
      s.requests[request_ref],
      &Request.handle_data(&1, new_data)
    )
  end

  defp process_response({:pong, request_ref}, s) do
    case pop_in(s.requests[request_ref]) do
      {{:ping, from}, s} ->
        # ping was initiated by a GenServer.call/3
        Connection.reply(from, :pong)

        s

      {nil, s} ->
        # ping was initiated by the keepalive timer
        update_in(s.keep_alive_timer, &KeepAliveTimer.clear_after_timer(&1, request_ref))
    end
  end

  defp process_response({:done, request_ref}, s) do
    {request, s} = pop_in(s.requests[request_ref])

    case request do
      %{type: {:subscription, subscriber, _through}, from: nil} ->
        send(subscriber, {:eos, request_ref, :dropped})

      %{from: from, response: response} ->
        Connection.reply(from, {:ok, response})
    end

    s
  end

  # coveralls-ignore-start
  defp process_response(_unknown, s), do: s
  # coveralls-ignore-stop

  defp request_and_stream_body(s, request, from, request_type) do
    with {:ok, conn, request_ref} <-
           Mint.HTTP2.request(s.conn, @post, request.path, request.headers, :stream),
         request = Request.new(request, request_ref, from, request_type),
         s = put_in(s.conn, conn),
         s = put_in(s.requests[request_ref], request),
         {:ok, s} <- Request.emit_messages(s, request) do
      {:ok, s}
    else
      # coveralls-ignore-start
      {:error, %__MODULE__{} = s, reason} ->
        {:error, s, reason}

      {:error, conn, reason} ->
        {:error, put_in(s.conn, conn), reason}
        # coveralls-ignore-stop
    end
  end

  defp do_connect(config) do
    Mint.HTTP.connect(config.scheme, config.host, config.port, config.mint_opts)
  end

  defp close_requests(s) do
    :ok = s.requests |> Map.values() |> Enum.each(&close_request/1)
  end

  defp close_request(%{
         type: {:subscription, proc, _through},
         from: nil,
         request_ref: request_ref
       }) do
    send(proc, {:eos, request_ref, :closed})
  end

  defp close_request(%{type: _, from: from}) do
    Connection.reply(from, {:error, :closed})
  end

  @doc false
  @spec fetch_subscription(%__MODULE__{}, reference()) :: {:ok, Request.t()} | :error
  def fetch_subscription(s, monitor_ref) do
    Enum.find_value(s.requests, :error, fn {_request_ref, request} ->
      request.monitor_ref == monitor_ref && {:ok, request}
    end)
  end

  @doc """
  Returns the list of read-only APIs

  This list is used to determine which requests are allowed for read-only
  clients.
  """
  @doc since: "0.8.0"
  @spec read_apis() :: %{(api :: module()) => [rpc :: atom()]}
  def read_apis, do: @read_apis

  @doc """
  Declares whether an API+RPC combination is read-only or not

  ## Examples

      iex> Spear.Connection.read_api?(Spear.Records.Streams, :Read)
      true
      iex> Spear.Connection.read_api?(Spear.Records.Streams, :Append)
      false
  """
  @doc since: "0.8.0"
  @spec read_api?(api :: module(), rpc :: atom()) :: boolean()
  def read_api?(api, rpc) when is_atom(api) and is_atom(rpc) do
    read_apis() |> Map.get(api, []) |> Enum.member?(rpc)
  end

  defp read_only_check(%Spear.Request{api: {api, rpc}}, %__MODULE__{
         config: %Spear.Connection.Configuration{read_only?: true}
       }) do
    if read_api?(api, rpc), do: :ok, else: {:error, :read_only}
  end

  defp read_only_check(_request, _s), do: :ok
end
