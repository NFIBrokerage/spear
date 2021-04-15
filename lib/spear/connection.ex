defmodule Spear.Connection do
  @default_opts [protocols: [:http2], mode: :active]

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

  * `:name` - the name of the GenServer. See `t:GenServer.name/0` for more
    information. When not provided, the spawned process is not aliased to a
    name and is only addressable through its PID.
  * `:connection_string` - (**required**) the connection string to parse
    containing all connection information
  * `:opts` - (default: `#{inspect(@default_opts)}`) a `t:Keyword.t/0`
    of options to pass directly to `Mint.HTTP.connect/4`. See the
    `Mint.HTTP.connect/4` documentation for a full reference. This can be used
    to specify a custom CA certificate when using EventStoreDB in secure mode
    (the default in 20+) with a custom set of certificates. The default options
    cannot be overridden: explicitly passed `:protocols` or `:mode` will be
    ignored.
  * `:credentials` - (default: `nil`) a pair (2-element) tuple providing a
    username and password to use for authentication with the EventStoreDB.
    E.g. the default username+password of `{"admin", "changeit"}`.

  ## TLS/SSL configuration and credentials

  See the [Security guide](guides/security.md) for information about
  certificates, credentials, and access control lists (ACLs).

  ## Examples

      iex> {:ok, conn} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")
      iex> Spear.stream!(conn, "es_supported_clients") |> Enum.take(3)
      [%Spear.Event{}, %Spear.Event{}, %Spear.Event{}]
  """

  # see the very similar original implementation of this from the Mint
  # documentation:
  # https://github.com/elixir-mint/mint/blob/796b8db097d69ede7163acba223ab2045c2773a4/pages/Architecture.md

  use Connection
  require Logger

  alias Spear.Connection.Request

  @post "POST"
  @closed %Mint.TransportError{reason: :closed}

  defstruct [:config, :credentials, :conn, requests: %{}]

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
        {Spear.Connection, connection_string: "esdb://localhost:2113"}
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
  def init(config) do
    if valid_config?(config) do
      {credentials, config} = Keyword.pop(config, :credentials)
      s = %__MODULE__{config: config, credentials: credentials}

      {:connect, :init, s}
    else
      Logger.error("""
      #{inspect(__MODULE__)} did not find enough information to start a connection.
      Check the #{inspect(__MODULE__)} moduledocs for configuration information.
      """)

      :ignore
    end
  end

  @impl Connection
  def connect(_, s) do
    case do_connect(s.config) do
      {:ok, conn} -> {:ok, %__MODULE__{s | conn: conn}}
      {:error, _reason} -> {:backoff, 500, s}
    end
  end

  @impl Connection
  def disconnect(info, %__MODULE__{conn: conn} = s) do
    {:ok, _conn} = Mint.HTTP.close(conn)

    case info do
      {:close, from} ->
        Connection.reply(from, {:ok, :closed})

        {:noconnect, %__MODULE__{s | conn: nil}}

      # coveralls-ignore-start
      :closed ->
        :ok
        {:connect, s.config, %__MODULE__{s | conn: nil}}
        # coveralls-ignore-stop
    end
  end

  @impl Connection
  def handle_cast(:connect, s), do: {:connect, s.config, s}

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
    request = Spear.Request.merge_credentials(request, s.credentials)

    case request_and_stream_body(s, request, from, type) do
      {:ok, s} ->
        {:noreply, s}

      # coveralls-ignore-start
      {:error, s, @closed} ->
        {:disconnect, :closed, {:error, :closed}, s}

      {:error, s, reason} ->
        {:reply, {:error, reason}, s}
        # coveralls-ignore-stop
    end
  end

  @impl Connection
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
    {{:ping, from}, s} = pop_in(s.requests[request_ref])

    Connection.reply(from, :pong)

    s
  end

  defp process_response({:done, request_ref}, s) do
    {%{response: response, from: from}, s} = pop_in(s.requests[request_ref])

    Connection.reply(from, {:ok, response})

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

  defp valid_config?(config) do
    case Keyword.fetch(config, :connection_string) do
      {:ok, connection_string} when is_binary(connection_string) ->
        true

      _ ->
        false
    end
  end

  defp do_connect(config) do
    uri =
      config
      |> Keyword.fetch!(:connection_string)
      |> URI.parse()
      |> set_scheme()

    opts =
      config
      |> Keyword.get(:opts, [])
      |> Keyword.merge(@default_opts)

    Mint.HTTP.connect(uri.scheme, uri.host, uri.port, opts)
  end

  defp set_scheme(%URI{} = uri) do
    scheme =
      with query when is_binary(query) <- uri.query,
           params = URI.decode_query(query),
           {:ok, "true"} <- Map.fetch(params, "tls") do
        :https
      else
        _ -> :http
      end

    %URI{uri | scheme: scheme}
  end
end
