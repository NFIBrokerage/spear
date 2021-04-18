defmodule Spear do
  @moduledoc """
  A sharp EventStoreDB 20+ client backed by mint

  ## Streams

  Spear uses the term _stream_ across different contexts. There are four
  possible contexts for the term _stream_ in Spear:

  - HTTP2 streams of data
  - gRPC stream requests, responses, and bidirectional communication
  - EventStoreDB streams of events
  - Elixir `Stream`s

  Descriptions of each are given in the [Streams guide](guides/streams.md).

  ## Connections

  Spear needs a connection to interact with an EventStoreDB. Spear provides
  the `Spear.Connection` GenServer for this purpose. Connections are referred
  to as "`conn`" in the documentation.

  Like an `Ecto.Repo`, it can be handy to have a module which itself represents
  a connection to an EventStoreDB. For this, Spear provides `Spear.Client`
  which allows one to call any function in `Spear` without the `conn` argument
  on the client module.

  ```elixir
  defmodule MyApp.MyClient do
    use Spear.Client,
      otp_app: :my_app
  end

  iex> MyApp.MyClient.start_link(connection_string: "esdb://localhost:2113")
  iex> MyApp.MyClient.stream!("my_stream") |> Enum.to_list()
  [
    %Spear.Event{},
    %Spear.Event{},
    ..
  ]
  ```

  See the `Spear.Client` module for more information.

  ## Record interfaces

  The `Spear.Records.*` modules provide macro interfaces for matching and
  creating messages sent and received from the EventStoreDB. These are mostly
  intended for internal uses such as the mapping between a
  `Spear.Records.Streams.read_resp/0` and a `t:Spear.Event.t/0`, but they can
  also be used to extract values from any raw response records (e.g. those
  returned from functions where the `raw?: true` option is passed).

      iex> import Spear.Records.Streams, only: [read_resp: 0, read_resp: 1]
      iex> event = Spear.stream!(conn, "my_stream", raw?: true) |> Enum.take(1) |> List.first()
      {:"event_store.client.streams.ReadResp", {checkpoint, ..}}
      iex> match?(read_resp(), event)
      true
      iex> match?(read_resp(content: {:checkpoint, _}), event)
      true

  Macros in these modules are generated with `Record.defrecord/2` with the
  contents extracted from the protobuf messages (indirectly via `:gpb`).
  """

  @doc """
  Collects an EventStoreDB stream into an enumerable

  This function may raise in cases where the gRPC requests fail to read events
  from the EventStoreDB (in cases of timeout or unavailability).

  This function does not raise if a stream does not exist (is empty), instead
  returning an empty enumerable `[]`.

  `connection` may be any valid GenServer name (including PIDs) for a process
  running the `Spear.Connection` GenServer.

  `stream_name` can be any stream, existing or not, including projected
  streams such as category streams or event-type streams. The `:all` atom
  may be passed as `stream_name` to read all events in the EventStoreDB.

  ## Options

  * `:from` - (default: `:start`) the EventStoreDB stream revision from which to
    read. Valid values include `:start`, `:end`, any non-negative integer
    representing the event number revision in the stream and events. Event
    numbers are exclusive (e.g. reading from `0` will first return the
    event numbered `1` in the stream, if one exists). `:start` and `:end`
    are treated as inclusive (e.g. `:start` will return the first event in
    the stream).  Events (either `Spear.Event` or ReadResp records) can also
    be supplied and will be treated as exclusive.
  * `:direction` - (default: `:forwards`) the direction in which to read the
    EventStoreDB stream. Valid values include `:forwards` and `:backwards`.
    Reading the EventStoreDB stream forwards will return events in the order
    in which they were written to the EventStoreDB; reading backwards will
    return events in the opposite order.
  * `:resolve_links?` - (default: `true`) whether or not to request that
    link references be resolved. See the moduledocs for more information
    about link resolution.
  * `:chunk_size` - (default: `128`) the number of events to read from the
    EventStoreDB at a time. Any positive integer is valid. See the enumeration
    characteristics section below for more information about how `:chunk_size`
    works and how to tune it.
  * `:timeout` - (default: `5_000` - 5s) the time allowed for the read of a
    single chunk of events in the EventStoreDB stream. This time is _not_
    cumulative: an EventStoreDB stream 100 events long which takes 5s to read
    each chunk may be read in chunks of 20 events culumaltively in 25s. A
    timeout of `5_001`ms would not raise a timeout error in that scenario
    (assuming the chunk read consistently takes `<= 5_000` ms).
  * `:raw?:` - (default: `false`) controls whether or not the enumerable
    `event_stream` is decoded to `Spear.Event` structs from their raw
    `ReadReq` output. Setting `raw?: true` prevents this transformation and
    leaves each event as a `ReadReq` record. See
    `Spear.Event.from_read_response/2` for more information.
  * `:credentials` - (default: `nil`) a two-tuple `{username, password}` to
    use as credentials for the request. This option overrides any credentials
    set in the connection configuration, if present. See the
    [Security guide](guides/security.md) for more details.

  ## Enumeration Characteristics

  The `event_stream` `t:Enumerable.t/0` returned by this function initially
  contains a buffer of bytes from the first read of the stream `stream_name`.
  This buffer potentially contains up to `:chunk_size` messages when run.
  The enumerable is written as a formula which abstracts away the chunking
  nature of the gRPC requests, however, so even though the EventStoreDB stream is
  read in chunks (per the `:chunk_size` option), the entire EventStoreDB stream
  can be read by running the enumeration (e.g. with `Enum.to_list/1`). Note
  that the stream will make a gRPC request to read more events whenever the
  buffer runs dry with up to `:chunk_size` messages filling the buffer on each
  request.

  `:chunk_size` is difficult to tune as it causes a tradeoff between (gRPC)
  request duration and number of messages added to the buffer. A higher
  `:chunk_size` may hydrate the buffer with more events and reduce the number
  of gRPC requests needed to read an entire stream, but it also increases
  the number of messages that will be sent over the network per request which
  could decrease reliability. Generally speaking, a lower `:chunk_size` is
  appropriate for streams in which the events are large and a higher
  `:chunk_size` is appropriate for streams with many small events. Manual
  tuning and trial-and-error can be used to find a performant `:chunk_size`
  setting for any individual environment.

  ## Examples

      iex> Spear.stream!(MyConnection, "es_supported_clients", chunk_size: 1) |> Enum.take(1)
      [
        %Spear.Event{
          body: %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
          id: "1fc908c1-af32-4d06-a9bd-3bf86a833fdf",
          metadata: %{..},
          type: "grpc-client"
        }
      ]
      # say we have 5 events in the "es_supported_clients" stream
      iex> Spear.stream!(MyConnection, "es_supported_clients", chunk_size: 3) |> Enum.count()
      5
  """
  @doc since: "0.1.0"
  @doc api: :streams
  @spec stream!(
          connection :: Spear.Connection.t(),
          stream_name :: String.t() | :all,
          opts :: Keyword.t()
        ) ::
          event_stream :: Enumerable.t()
  def stream!(connection, stream_name, opts \\ []) do
    default_stream_opts = [
      from: :start,
      direction: :forwards,
      chunk_size: 128,
      resolve_links?: true,
      through: fn stream -> Stream.map(stream, &Spear.Event.from_read_response/1) end,
      timeout: 5_000,
      raw?: false,
      credentials: nil
    ]

    opts = Keyword.merge(default_stream_opts, opts)

    through =
      if opts[:raw?] do
        & &1
      else
        opts[:through]
      end

    Spear.Reading.Stream.new!(
      connection: connection,
      stream: stream_name,
      from: opts[:from],
      max_count: opts[:chunk_size],
      direction: opts[:direction],
      resolve_links?: opts[:resolve_links?],
      timeout: opts[:timeout]
    )
    |> through.()
  end

  @doc """
  Reads a chunk of events from an EventStoreDB stream into an enumerable

  Unlike `stream!/3`, this function will only read one chunk of events at a time
  specified by the `:max_count` option. This function also does not raise in
  cases of error, instead returning an ok- or error-tuple.

  If the `stream_name` EventStoreDB stream does not exist (is empty) and the
  gRPC request succeeds for this function, `{:ok, []}` will be returned.

  ## Options

  * `:from` - (default: `:start`) the EventStoreDB stream revision from which to
    read. Valid values include `:start`, `:end`, any non-negative integer
    representing the event number revision in the stream and events. Event
    numbers are exclusive (e.g. reading from `0` will first return the
    event numbered `0` in the stream, if one exists). `:start` and `:end`
    are treated as inclusive (e.g. `:start` will return the first event in
    the stream).  Events (either `Spear.Event` or ReadResp records) can also
    be supplied and will be treated as exclusive.
  * `:direction` - (default: `:forwards`) the direction in which to read the
    EventStoreDB stream. Valid values include `:forwards` and `:backwards`.
    Reading the EventStoreDB stream forwards will return events in the order
    in which they were written to the EventStoreDB; reading backwards will
    return events in the opposite order.
  * `:resolve_links?` - (default: `true`) whether or not to request that
    link references be resolved. See the moduledocs for more information
    about link resolution.
  * `:max_count` - (default: `42`) the maximum number of events to read from
    the EventStoreDB stream. Any positive integer is valid. Even if the stream
    is longer than this `:max_count` option, only `:max_count` events will
    be returned from this function. `:infinity` is _not_ a valid value for
    `:max_count`. Use `stream!/3` for an enumerable which reads an EventStoreDB
    stream in its entirety in chunked network requests.
  * `:timeout` - (default: `5_000` - 5s) the time allowed for the read of the
    single chunk of events in the EventStoreDB stream. Note that the gRPC request
    which reads events from the EventStoreDB is front-loaded in this function:
    the `:timeout` covers the time it takes to read the events. The timeout
    may be exceeded
  * `:raw?:` - (default: `false`) controls whether or not the enumerable
    `event_stream` is decoded to `Spear.Event` structs from their raw
    `ReadReq` output. Setting `raw?: true` prevents this transformation and
    leaves each event as a `ReadReq` record. See
    `Spear.Event.from_read_response/2` for more information.
  * `:credentials` - (default: `nil`) a two-tuple `{username, password}` to
    use as credentials for the request. This option overrides any credentials
    set in the connection configuration, if present. See the
    [Security guide](guides/security.md) for more details.

  ## Timing and Timeouts

  The gRPC request which reads events from the EventStoreDB is front-loaded
  in this function: this function returns immediately after receiving all data
  off the wire from the network request. This means that the `:timeout` option
  covers the gRPC request and response time but not any time spend decoding
  the response (see the Enumeration Characteristics section below for more
  details on how the enumerable decodes messages).

  The default timeout of 5s may not be enough time in cases of either reading
  very large numbers of events or reading events with very large bodies.

  Note that _up to_ the `:max_count` of events is returned from this call
  depending on however many events are in the EventStoreDB stream being read.
  When tuning the `:timeout` option, make sure to test against a stream which
  is at least as long as `:max_count` events.

  ## Enumeration Characteristics

  The `event_stream` `t:Enumerable.t/0` returned in the success case of this
  function is a wrapper around the bytes received from the gRPC response. Note
  that when the `{:ok, event_stream}` is returned, the gRPC request has already
  concluded.

  This offers only marginal performance improvement: an enumerable is returned
  mostly for consistency in the Spear API.

  ## Examples

      # say we have 5 events in the stream "es_supported_clients"
      iex> {:ok, events} = Spear.read_stream(conn, "es_supported_clients", max_count: 2)
      iex> events |> Enum.count()
      2
      iex> {:ok, events} = Spear.read_stream(conn, "es_supported_clients", max_count: 10)
      iex> events |> Enum.count()
      5
      iex> events |> Enum.take(1)
      [
        %Spear.Event{
          body: %{"languages" => ["typescript", "javascript"], "runtime" => "NodeJS"},
          id: "1fc908c1-af32-4d06-a9bd-3bf86a833fdf",
          metadata: %{..},
          type: "grpc-client"
        }
      ]
  """
  @doc since: "0.1.0"
  @doc api: :streams
  @spec read_stream(Spear.Connection.t(), String.t(), Keyword.t()) ::
          {:ok, event_stream :: Enumerable.t()} | {:error, any()}
  def read_stream(connection, stream_name, opts \\ []) do
    default_read_opts = [
      from: :start,
      direction: :forwards,
      max_count: 42,
      resolve_links?: true,
      through: fn stream -> Stream.map(stream, &Spear.Event.from_read_response/1) end,
      timeout: 5_000,
      raw?: false,
      credentials: nil
    ]

    opts = Keyword.merge(default_read_opts, opts)

    through =
      if opts[:raw?] do
        & &1
      else
        opts[:through]
      end

    chunk_read_response =
      Spear.Reading.Stream.read_chunk(
        connection: connection,
        stream: stream_name,
        from: opts[:from],
        max_count: opts[:max_count],
        filter: opts[:filter],
        direction: opts[:direction],
        resolve_links?: opts[:resolve_links?],
        timeout: opts[:timeout]
      )

    case chunk_read_response do
      {:ok, stream} ->
        {:ok, through.(stream)}

      # coveralls-ignore-start
      error ->
        error

        # coveralls-ignore-stop
    end
  end

  @doc """
  Appends an enumeration of events to an EventStoreDB stream

  `event_stream` is an enumerable which may either be a
  collection of `t:Spear.Event.t/0` structs or more low-level
  `Spear.Records.Streams.append_resp/0` records. In cases where the enumerable
  produces `t:Spear.Event.t/0` structs, they will be lazily mapped to
  `AppendReq` records before being encoded to wire data.

  See the [Writing Events](guides/writing_events.md) guide for more information
  about writing events.

  ## Options

  * `:expect` - (default: `:any`) the expectation to set on the
    status of the stream. The write will fail if the expectation fails. See
    `Spear.ExpectationViolation` for more information about expectations.
  * `:timeout` - (default: `5_000` - 5s) the GenServer timeout for calling
    the RPC.
  * `:raw?` - (default: `false`) a boolean which controls whether the return
    signature should be a simple `:ok | {:error, any()}` or
    `{:ok, AppendResp.t()} | {:error, any()}`. This can be used to extract
    metadata and information from the append response which is not available
    through the simplified return API, such as the stream's revision number
    after writing the events.
  * `:credentials` - (default: `nil`) a two-tuple `{username, password}` to
    use as credentials for the request. This option overrides any credentials
    set in the connection configuration, if present. See the
    [Security guide](guides/security.md) for more details.

  ## Examples

      iex> [Spear.Event.new("es_supported_clients", %{})]
      ...> |> Spear.append(conn, expect: :exists)
      :ok
      iex> [Spear.Event.new("es_supported_clients", %{})]
      ...> |> Spear.append(conn, expect: :empty)
      {:error, %Spear.ExpectationViolation{current: 1, expected: :empty}}
  """
  @doc since: "0.1.0"
  @doc api: :streams
  @spec append(
          event_stream :: Enumerable.t(),
          connection :: Spear.Connection.t(),
          stream_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, reason :: Spear.ExpectationViolation.t() | any()}
  def append(event_stream, conn, stream_name, opts \\ []) when is_binary(stream_name) do
    import Spear.Records.Streams, only: [append_resp: 1]

    default_write_opts = [
      expect: :any,
      raw?: false,
      stream: stream_name
    ]

    opts = default_write_opts |> Keyword.merge(opts)
    params = Enum.into(opts, %{})

    messages =
      [Spear.Writing.build_append_request(params)]
      |> Stream.concat(event_stream)
      |> Stream.map(&Spear.Writing.to_append_request/1)

    case request(
           conn,
           Spear.Records.Streams,
           :Append,
           messages,
           Keyword.take(opts, [:credentials, :timeout])
         ) do
      {:ok, append_resp(result: {:success, _})} ->
        :ok

      {:ok, append_resp(result: {:wrong_expected_version, expectation_violation})} ->
        {:error, Spear.Writing.map_expectation_violation(expectation_violation)}

      error ->
        error
    end
  end

  @doc """
  Subscribes a process to an EventStoreDB stream

  Unlike `read_stream/3` or `stream!/3`, this function does not return an
  enumerable. Instead the `subscriber` process is signed up to receive messages
  for subscription events. Events are emitted in order as info messages with
  the signature

  ```elixir
  Spear.Event.t() | Spear.Filter.Checkpoint.t()
  ```

  or if the `raw?: true` option is provided,
  `Spear.Records.Streams.read_resp/0` records will be returned.

  This function will block the caller until the subscription has been
  confirmed by the EventStoreDB.

  When the subscription is terminated, the subscription process will
  receive a message in the form of `{:eos, reason}`. `{:eos, :closed}` is
  currently the only implemented end-of-stream reason and it occurs when
  the connection is severed between Spear and the EventStoreDB. If this
  message is received, the subscription is considered to be concluded and the
  subscription process must re-subscribe from the last received event or
  checkpoint to resume the subscription.

  ## Options

  * `:from` - (default: `:start`) the EventStoreDB stream revision from which to
    read. Valid values include `:start`, `:end`, any non-negative integer
    representing the event number revision in the stream and events. Event
    numbers are exclusive (e.g. reading from `0` will first return the
    event numbered `1` in the stream, if one exists). `:start` and `:end`
    are treated as inclusive (e.g. `:start` will return the first event in
    the stream).  Events and checkpoints (`t:Spear.Event.t/0`, ReadResp
    records, or `t:Spear.Filter.Checkpoint.t/0`) can also be supplied and will
    be treated as exclusive.
  * `:filter` - (default: `nil`) the server-side filter to apply. This option
    is only valid if the `stream_name` is `:all`. See `Spear.Filter` for more
    information.
  * `:resolve_links?` - (default: `true`) whether or not to request that
    link references be resolved. See the moduledocs for more information
    about link resolution.
  * `:timeout` - (default: `5_000`) the time to wait for the EventStoreDB
    to confirm the subscription request.
  * `:raw?` - (default: `false`) controls whether the events are sent as
    raw `ReadResp` records or decoded into `t:Spear.Event.t/0`s
  * `:credentials` - (default: `nil`) a two-tuple `{username, password}` to
    use as credentials for the request. This option overrides any credentials
    set in the connection configuration, if present. See the
    [Security guide](guides/security.md) for more details.

  ## Examples

      # say there are 3 events in the EventStoreDB stream "my_stream"
      iex> {:ok, sub} = Spear.subscribe(conn, self(), "my_stream", from: 0)
      {:ok, #Reference<0.1160763861.3015180291.51238>}
      iex> flush
      %Spear.Event{} # second event
      %Spear.Event{} # third event
      :ok
      iex> Spear.cancel_subscription(conn, sub)
      :ok

      iex> {:ok, sub} = Spear.subscribe(conn, self(), :all, filter: Spear.Filter.exclude_system_events())
      iex> flush
      %Spear.Filter.Checkpoint{}
      %Spear.Filter.Checkpoint{}
      %Spear.Event{}
      %Spear.Event{}
      %Spear.Filter.Checkpoint{}
      %Spear.Event{}
      %Spear.Filter.Checkpoint{}
      :ok
      iex> GenServer.call(conn, :close)
      {:ok, :closed}
      iex> flush
      {:eos, :closed}
  """
  @doc since: "0.1.0"
  @doc api: :streams
  @spec subscribe(
          connection :: Spear.Connection.t(),
          subscriber :: pid() | GenServer.name(),
          stream_name :: String.t() | :all,
          opts :: Keyword.t()
        ) :: {:ok, subscription_reference :: reference()} | {:error, any()}
  def subscribe(conn, subscriber, stream_name, opts \\ [])

  def subscribe(conn, subscriber, stream_name, opts)
      when (is_binary(stream_name) or stream_name == :all) and is_list(opts) do
    default_subscribe_opts = [
      direction: :forwards,
      from: :start,
      filter: nil,
      resolve_links?: true,
      timeout: 5_000,
      raw?: false,
      through: &Spear.Reading.decode_read_response/1,
      credentials: nil
    ]

    opts =
      default_subscribe_opts
      |> Keyword.merge(opts)
      |> Keyword.merge(stream: stream_name, subscriber: subscriber)

    through =
      if opts[:raw?] do
        & &1
      else
        opts[:through]
      end

    request = opts |> Enum.into(%{}) |> Spear.Reading.build_subscribe_request()

    # YARD deal with broken subscriptions
    Connection.call(conn, {{:subscription, subscriber, through}, request}, opts[:timeout])
  end

  @doc """
  Cancels a subscription

  This function will cancel a subscription if the provided
  `subscription_reference` exists, but is idempotent: if the
  `subscription_reference` is not an active subscription reference, `:ok` will
  be returned.

  Subscriptions are automatically cancelled when a subscribe process exits.

  ## Examples

      iex> {:ok, subscription} = Spear.subscribe(conn, self(), "my_stream")
      {:ok, #Reference<0.4293953740.2750676995.30541>}
      iex> Spear.cancel_subscription(conn, subscription)
      :ok
      iex> Spear.cancel_subscription(conn, subscription)
      :ok
  """
  @doc since: "0.1.0"
  @doc api: :streams
  @spec cancel_subscription(
          connection :: Spear.Connection.t(),
          subscription_reference :: reference(),
          timeout()
        ) :: :ok | {:error, any()}
  def cancel_subscription(conn, subscription_reference, timeout \\ 5_000)
      when is_reference(subscription_reference) do
    Connection.call(conn, {:cancel, subscription_reference}, timeout)
  end

  @doc """
  Deletes an EventStoreDB stream

  EventStoreDB supports two kinds of stream deletions: soft-deletes and
  tombstones. By default this function will perform a soft-delete. Pass the
  `tombstone?: true` option to tombstone the stream.

  Soft-deletes make the events in the specified stream no longer accessible
  through reads. A scavenge operation will reclaim the disk space taken by
  any soft-deleted events. New events may be written to a soft-deleted stream.
  When reading soft-deleted streams, `:from` options of `:start` and `:end`
  will behave as expected, but all events in the stream will have revision
  numbers off-set by the number of deleted events.

  Tombstoned streams may not be written to ever again. Attempting to write
  to a tombstoned stream will fail with a gRPC `:failed_precondition` error

  ```elixir
  iex> [Spear.Event.new("delete_test", %{})] |> Spear.append(conn, "delete_test_0")
  :ok
  iex> Spear.delete_stream(conn, "delete_test_0", tombstone?: true)
  :ok
  iex> [Spear.Event.new("delete_test", %{})] |> Spear.append(conn, "delete_test_0")
  {:error,
   %Spear.Grpc.Response{
     data: "",
     message: "Event stream 'delete_test_0' is deleted.",
     status: :failed_precondition,
     status_code: 9
   }}
  ```

  ## Options

  * `:tombstone?` - (default: `false`) controls whether the stream is
    soft-deleted or tombstoned.
  * `:timeout` - (default: `5_000` - 5s) the time allowed to block while
    waiting for the EventStoreDB to delete the stream.
  * `:expect` - (default: `:any`) the expected state of the stream when
    performing the deleteion. See `append/4` and `Spear.ExpectationViolation`
    for more information.
  * `:credentials` - (default: `nil`) a two-tuple `{username, password}` to
    use as credentials for the request. This option overrides any credentials
    set in the connection configuration, if present. See the
    [Security guide](guides/security.md) for more details.

  ## Examples

      iex> Spear.append(events, conn, "my_stream")
      :ok
      iex> Spear.delete_stream(conn, "my_stream")
      :ok
      iex> Spear.stream!(conn, "my_stream") |> Enum.to_list()
      []
  """
  @doc since: "0.1.0"
  @doc api: :streams
  @spec delete_stream(
          connection :: Spear.Connection.t(),
          stream_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def delete_stream(conn, stream_name, opts \\ []) when is_binary(stream_name) do
    default_delete_opts = [
      tombstone?: false,
      timeout: 5_000,
      expect: :any,
      credentials: nil
    ]

    opts =
      default_delete_opts
      |> Keyword.merge(opts)
      |> Keyword.put(:stream, stream_name)

    request = opts |> Enum.into(%{}) |> Spear.Writing.build_delete_request()

    with {:ok, %Spear.Connection.Response{} = response} <-
           Connection.call(conn, {:request, request}, opts[:timeout]),
         %Spear.Grpc.Response{status: :ok} <-
           Spear.Grpc.Response.from_connection_response(response) do
      :ok
    else
      # coveralls-ignore-start
      {:error, reason} -> {:error, reason}
      # coveralls-ignore-stop
      %Spear.Grpc.Response{} = response -> {:error, response}
    end
  end

  @doc """
  Pings a connection

  This can be used to ensure that the connection process is alive, or to
  roughly measure the latency between the connection process and EventStoreDB.

  ## Examples

      iex> Spear.ping(conn)
      :pong
  """
  @doc since: "0.1.2"
  @doc api: :utils
  @spec ping(connection :: Spear.Connection.t(), timeout()) :: :pong | {:error, any()}
  def ping(conn, timeout \\ 5_000), do: Connection.call(conn, :ping, timeout)

  @doc """
  Sets the global stream ACL

  This function appends an event to the `$streams` EventStoreDB stream
  detailing how the EventStoreDB should allow access to user and system
  streams (with the `user_acl` and `system_acl` arguments, respectively).

  See the [security guide](guides/security.md) for more information.

  ## Options

  * `:json_encode!` - (default: `Jason.encode!/1`) a 1-arity JSON encoding
    function used to serialize the event. This event must be JSON encoded
    in order for the EventStoreDB to consider it valid.

  Remaining options are passed to `Spear.append/4`. The `:expect` option
  will be applied to the `$streams` system stream, so one could attempt to
  set the initial ACL by passing `expect: :empty`.

  ## Examples

  This recreates the default ACL:

      iex> Spear.set_global_acl(conn, Spear.Acl.allow_all(), Spear.Acl.admins_only())
      :ok
  """
  @doc since: "0.1.3"
  @doc api: :utils
  @spec set_global_acl(
          connection :: Spear.Connection.t(),
          user_acl :: Spear.Acl.t(),
          system_acl :: Spear.Acl.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def set_global_acl(conn, user_acl, system_acl, opts \\ [])

  def set_global_acl(conn, %Spear.Acl{} = user_acl, %Spear.Acl{} = system_acl, opts) do
    {json_encode!, opts} = Keyword.pop(opts, :json_encode!)
    json_encode! = json_encode! || (&Jason.encode!/1)

    Spear.Writing.build_global_acl_event(user_acl, system_acl, json_encode!)
    |> List.wrap()
    |> Spear.append(conn, "$streams", opts)
  end

  @doc """
  Determines the metadata stream for any given stream

  Meta streams are used by the EventStoreDB to store some internal information
  about a stream, and to configure features such setting time-to-lives for
  events or streams.

  ## Examples

      iex> Spear.meta_stream("es_supported_clients")
      "$$es_supported_clients"
  """
  @doc since: "0.1.3"
  @doc api: :utils
  @spec meta_stream(stream :: String.t()) :: String.t()
  def meta_stream(stream) when is_binary(stream), do: "$$" <> stream

  @doc """
  Queries the metadata for a stream

  Note that the `stream` argument is passed through `meta_stream/1` before
  being read. It is not necessary to call that function on the stream name
  before passing it as `stream`.

  If no metadata has been set on a stream `{:error, :unset}` is returned.

  ## Options

  Under the hood, `get_stream_metadata/3` uses `read_stream/3` and all options
  are passed directly to that function. These options are overridden, however,
  and cannot be changed:

  * `:direction`
  * `:from`
  * `:max_count`
  * `:raw?`

  ## Examples

      iex> Spear.get_stream_metadata(conn, "my_stream")
      {:error, :unset}
      iex> Spear.get_stream_metadata(conn, "some_stream_with_max_count")
      {:ok, %Spear.StreamMetadata{max_count: 50_000, ..}}
  """
  @doc since: "0.1.3"
  @doc api: :streams
  @spec get_stream_metadata(
          connection :: Spear.Connection.t(),
          stream :: String.t(),
          opts :: Keyword.t()
        ) :: {:ok, Spear.StreamMetadata.t()} | {:error, any()}
  def get_stream_metadata(conn, stream, opts \\ []) do
    stream = meta_stream(stream)

    opts =
      opts
      |> Keyword.merge(
        direction: :backwards,
        from: :end,
        max_count: 1,
        raw?: false
      )

    with {:ok, event_stream} <- read_stream(conn, stream, opts),
         [%Spear.Event{} = event] <- Enum.take(event_stream, 1) do
      {:ok, Spear.StreamMetadata.from_spear_event(event)}
    else
      [] ->
        {:error, :unset}

      # coveralls-ignore-start
      {:error, reason} ->
        {:error, reason}
        # coveralls-ignore-stop
    end
  end

  @doc """
  Sets a stream's metadata

  Note that the `stream` argument is passed through `meta_stream/1` before
  being read. It is not necessary to call that function on the stream name
  before passing it as `stream`.

  ## Options

  This function uses `append/4` under the hood. All options are passed to
  the `opts` argument of `append/4`.

  ## Examples

      # only allow admins to read, write, and delete the stream (or stream metadata)
      iex> metadata = %Spear.StreamMetadata{acl: Spear.Acl.admins_only()}
      iex> Spear.set_stream_metadata(conn, stream, metadata)
      :ok
  """
  @doc since: "0.1.3"
  @doc api: :streams
  @spec set_stream_metadata(
          connection :: Spear.Connection.t(),
          stream :: String.t(),
          metadata :: Spear.StreamMetadata.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def set_stream_metadata(conn, stream, metadata, opts \\ [])

  def set_stream_metadata(conn, stream, %Spear.StreamMetadata{} = metadata, opts)
      when is_binary(stream) do
    Spear.Event.new("$metadata", Spear.StreamMetadata.to_map(metadata))
    |> List.wrap()
    |> append(conn, meta_stream(stream), opts)
  end

  @doc """
  Creates an EventStoreDB user

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "open sesame", ["$ops"], credentials: {"admin", "changeit"})
      :ok
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec create_user(
          Spear.Connection.t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()],
          Keyword.t()
        ) :: :ok | {:error, any()}
  def create_user(conn, full_name, login_name, password, groups, opts \\ []) do
    import Spear.Records.Users

    message =
      create_req(
        options:
          create_req_options(
            full_name: full_name,
            login_name: login_name,
            password: password,
            groups: groups
          )
      )

    case request(conn, Spear.Records.Users, :Create, [message], opts) do
      {:ok, create_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Updates an existing EventStoreDB user

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "open sesame", ["$ops"], credentials: {"admin", "changeit"})
      :ok
      iex> Spear.update_user(conn, "Aladdin", "aladdin", "open sesame", ["$admins"], credentials: {"admin", "changeit"})
      :ok
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec update_user(
          Spear.Connection.t(),
          String.t(),
          String.t(),
          String.t(),
          [String.t()],
          Keyword.t()
        ) :: :ok | {:error, any()}
  def update_user(conn, full_name, login_name, password, groups, opts \\ []) do
    import Spear.Records.Users

    message =
      update_req(
        options:
          update_req_options(
            full_name: full_name,
            login_name: login_name,
            password: password,
            groups: groups
          )
      )

    case request(conn, Spear.Records.Users, :Update, [message], opts) do
      {:ok, update_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Deletes a user from the EventStoreDB

  EventStoreDB users are deleted by the `login_name` parameter as passed
  to `Spear.create_user/6`.

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "open sesame", ["$ops"], credentials: {"admin", "changeit"})
      :ok
      iex> Spear.delete_user(conn, "aladdin", credentials: {"admin", "changeit"})
      :ok
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec delete_user(Spear.Connection.t(), String.t(), Keyword.t()) :: :ok | {:error, any()}
  def delete_user(conn, login_name, opts \\ []) do
    import Spear.Records.Users

    message = delete_req(options: delete_req_options(login_name: login_name))

    case request(conn, Spear.Records.Users, :Update, [message], opts) do
      {:ok, delete_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Enables a user to make requests against the EventStoreDB

  Disabling and enabling users are an alternative to repeatedly creating and
  deleting users and is suitable for when a user needs to be temporarily
  denied access.

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.disable_user(conn, "aladdin")
      :ok
      iex> Spear.enable_user(conn, "aladdin")
      :ok
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec enable_user(Spear.Connection.t(), String.t(), Keyword.t()) :: :ok | {:error, any()}
  def enable_user(conn, login_name, opts \\ []) do
    import Spear.Records.Users

    message = enable_req(options: enable_req_options(login_name: login_name))

    case request(conn, Spear.Records.Users, :Enable, [message], opts) do
      {:ok, enable_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Disables a user's ability to make requests against the EventStoreDB

  This can be used in conjunction with `Spear.enable_user/3` to temporarily
  deny access to a user as an alternative to deleting and creating the user.
  Enabling and disabling users does not require the password of the user:
  just that requestor to be in the `$admins` group.

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.enable_user(conn, "aladdin")
      :ok
      iex> Spear.disable_user(conn, "aladdin")
      :ok
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec disable_user(Spear.Connection.t(), String.t(), Keyword.t()) :: :ok | {:error, any()}
  def disable_user(conn, login_name, opts \\ []) do
    import Spear.Records.Users

    message = disable_req(options: disable_req_options(login_name: login_name))

    case request(conn, Spear.Records.Users, :Disable, [message], opts) do
      {:ok, disable_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Fetches details about an EventStoreDB user

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "open sesame", ["$ops"])
      :ok
      iex> Spear.user_details(conn, "aladdin")
      {:ok,
       %Spear.User{
         enabled?: true,
         full_name: "Aladdin",
         groups: ["$ops"],
         last_updated: ~U[2021-04-18 16:48:38.583313Z],
         login_name: "aladdin"
       }}
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec user_details(Spear.Connection.t(), String.t(), Keyword.t()) :: :ok | {:error, any()}
  def user_details(conn, login_name, opts \\ []) do
    import Spear.Records.Users

    message = details_req(options: details_req_options(login_name: login_name))

    case request(conn, Spear.Records.Users, :Details, [message], opts) do
      {:ok, details_resp() = details_resp} -> {:ok, Spear.User.from_details_resp(details_resp)}
      error -> error
    end
  end

  @doc """
  Changes a user's password by providing the current password

  This can be accomplished regardless of the current credentials since the
  user's current password is provided.

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "changeit", ["$ops"])
      :ok
      iex> Spear.change_user_password(conn, "aladdin", "changeit", "open sesame")
      :ok
  """
  @doc api: :users
  def change_user_password(conn, login_name, current_password, new_password, opts \\ []) do
    import Spear.Records.Users

    message =
      change_password_req(
        options:
          change_password_req_options(
            login_name: login_name,
            current_password: current_password,
            new_password: new_password
          )
      )

    case request(conn, Spear.Records.Users, :ChangePassword, [message], opts) do
      {:ok, change_password_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Resets a user's password

  This can be only requested by a user in the `$admins` group. The current
  password is not passed in this request, so this function is suitable for
  setting a new password when the current password is lost.

  ## Options

  All options are passed to `Spear.request/5`.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "changeit", ["$ops"])
      :ok
      iex> Spear.reset_user_password(conn, "aladdin", "open sesame", credentials: {"admin", "changeit"})
      :ok
  """
  @doc since: "0.3.0"
  @doc api: :users
  @spec reset_user_password(Spear.Connection.t(), String.t(), String.t(), Keyword.t()) ::
          :ok | {:error, any()}
  def reset_user_password(conn, login_name, new_password, opts \\ []) do
    import Spear.Records.Users

    message =
      reset_password_req(
        options:
          reset_password_req_options(
            login_name: login_name,
            new_password: new_password
          )
      )

    case request(conn, Spear.Records.Users, :ResetPassword, [message], opts) do
      {:ok, reset_password_resp()} -> :ok
      error -> error
    end
  end

  @doc """
  Performs a generic request synchronously

  This is appropriate for many operations across the Users, Streams, and
  Operations APIs but not suitable for `Spear.subscribe/4` or the
  Persistent Subscriptions API.

  `message` must be an enumeration of records as created by the Record
  Interfaces. Lazy stream enumerations are allowed and are not run until each
  element is serialized over the wire.

  This function is mostly used under-the-hood to implement functions in
  `Spear` such as `Spear.create_user/5`, but may be used generically.

  ## Options

  * `:timeout` - (default: `5_000`ms - 5s) the GenServer timeout: the maximum
    time allowed to wait for this request to complete.
  * `:credentials` - (default: `nil`) the username and password to use to make
    the request. Overrides the connection-level credentials if provided.
    Connection-level credentials are used as the default if not provided.

  ## Examples

      iex> alias Spear.Records.Users
      iex> require Users
      iex> message = Users.enable_req(options: Users.enable_req_options(login_name: "my_user"))
      iex> Spear.request(conn, Users, :Enable, [message], credentials: {"admin", "changeit"})
      {:ok, Users.enable_resp()}
  """
  @doc since: "0.3.0"
  @doc api: :utils
  @spec request(Spear.Connection.t(), module(), atom(), Enumerable.t(), Keyword.t()) ::
          {:ok, tuple() | Enumerable.t()} | {:error, any()}
  def request(conn, api, rpc, messages, opts) do
    opts = [timeout: 5_000, credentials: nil] |> Keyword.merge(opts)

    request =
      %Spear.Request{
        api: {api, rpc},
        messages: messages,
        credentials: opts[:credentials]
      }
      |> Spear.Request.expand()

    with {:ok, %Spear.Connection.Response{} = response} <-
           Connection.call(conn, {:request, request}, opts[:timeout]),
         %Spear.Grpc.Response{status: :ok, data: data} <-
           Spear.Grpc.Response.from_connection_response(response) do
      {:ok, data}
    else
      # coveralls-ignore-start
      {:error, reason} -> {:error, reason}
      # coveralls-ignore-stop
      %Spear.Grpc.Response{} = response -> {:error, response}
    end
  end

  @doc """
  Parses an EventStoreDB timestamp into a `DateTime.t()` in UTC time.

  ## Examples

      iex> Spear.parse_stamp(16187636458580612)
      {:ok, ~U[2021-04-18 16:34:05.858061Z]}
  """
  @doc since: "0.3.0"
  @doc api: :utils
  @spec parse_stamp(pos_integer()) :: {:ok, DateTime.t()} | {:error, atom()}
  def parse_stamp(ticks_since_epoch) when is_integer(ticks_since_epoch) do
    ticks_since_epoch
    |> div(10)
    |> DateTime.from_unix(:microsecond)
  end
end
