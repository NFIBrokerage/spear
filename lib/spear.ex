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
      {:"event_store.client.streams.ReadResp", {:checkpoint, ..}}
      iex> match?(read_resp(), event)
      true
      iex> match?(read_resp(content: {:checkpoint, _}), event)
      true

  Macros in these modules are generated with `Record.defrecord/2` with the
  contents extracted from the protobuf messages (indirectly via `:gpb`).
  """

  import Spear.Records.Shared, only: [empty: 0]
  require Spear.Records.Streams, as: Streams
  require Spear.Records.Users, as: Users
  require Spear.Records.Operations, as: Operations
  require Spear.Records.Gossip, as: Gossip
  require Spear.Records.Persistent, as: Persistent
  require Spear.Records.Monitoring, as: Monitoring
  require Spear.Records.Shared, as: Shared

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
    numbers are inclusive (e.g. reading from `0` will first return the
    event with revision `0` in the stream, if one exists). `:start` and `:end`
    are treated as inclusive (e.g. `:start` will return the first event in
    the stream).  Events (either `Spear.Event` or ReadResp records) can also
    be supplied and will be treated as inclusive.
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
    `Spear.Records.Streams.read_resp/0` output. Setting `raw?: true` prevents
    this transformation and leaves each event as a `ReadResp` record. See
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

    opts =
      default_stream_opts
      |> Keyword.merge(opts)
      |> Keyword.put(:connection, connection)
      |> Keyword.put(:stream, stream_name)

    through =
      if opts[:raw?] do
        & &1
      else
        opts[:through]
      end

    Spear.Reading.Stream.new!(opts) |> through.()
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
    numbers are inclusive (e.g. reading from `0` will first return the
    event with revision `0` in the stream, if one exists). `:start` and `:end`
    are treated as inclusive (e.g. `:start` will return the first event in
    the stream).  Events (either `Spear.Event` or ReadResp records) can also
    be supplied and will be treated as inclusive.
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
    `ReadResp` output. Setting `raw?: true` prevents this transformation and
    leaves each event as a `Spear.Records.Streams.read_resp/0` record. See
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

    opts =
      default_read_opts
      |> Keyword.merge(opts)
      |> Keyword.put(:connection, connection)
      |> Keyword.put(:stream, stream_name)

    through =
      if opts[:raw?] do
        & &1
      else
        opts[:through]
      end

    with {:ok, stream} <- Spear.Reading.Stream.read_chunk(opts) do
      {:ok, through.(stream)}
    end
  end

  @doc """
  Appends an enumeration of events to an EventStoreDB stream

  `event_stream` is an enumerable which may either be a
  collection of `t:Spear.Event.t/0` structs or more low-level
  `Spear.Records.Streams.append_resp/0` records. In cases where the enumerable
  produces `t:Spear.Event.t/0` structs, they will be lazily mapped to
  `Spear.Records.Streams.append_req/0` records before being encoded to wire
  data.

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
           Streams,
           :Append,
           messages,
           Keyword.take(opts, [:credentials, :timeout])
         ) do
      {:ok, Streams.append_resp(result: {:success, _})} ->
        :ok

      {:ok, Streams.append_resp(result: {:wrong_expected_version, expectation_violation})} ->
        {:error, Spear.Writing.map_expectation_violation(expectation_violation)}

      error ->
        error
    end
  end

  @doc """
  Appends an enumeration of events to an EventStoreDB stream

  ## Options

  * `:expect` - (default: `:any`) the expectation to set on the
    status of the stream. The write will fail if the expectation fails. See
    `Spear.ExpectationViolation` for more information about expectations.
  * `:deadline` - TODO
  * `:send_ack_to` - (default: `self()`) a process or process name which
    should receive acknowledgement messages detailing whether a batch has
    succeded or failed to be committed by the deadline.
  * `:done?` - (default: false) controls whether this batch of events should
    close out the entire batch-append request. Attempting to send more batches
    on the same `batch_id` after a chunk with the `:done?` flag set to `true`
    will fail.
  * `:raw?` - (default: `false`) a boolean which controls whether the return
    signature should TODO
  * `:credentials` - (default: `nil`) a two-tuple `{username, password}` to
    use as credentials for the request. This option overrides any credentials
    set in the connection configuration, if present. See the
    [Security guide](guides/security.md) for more details.

  ## Examples

      iex> TODO.todo()
  """
  @doc since: "0.10.0"
  @doc api: :streams
  @spec append_batch(
          event_stream :: Enumerable.t(),
          connection :: Spear.Connection.t(),
          batch_id :: reference() | :new,
          stream_name :: String.t(),
          opts :: Keyword.t()
        ) :: {:ok, batch_id :: reference()} | {:error, term()}
  def append_batch(event_stream, conn, batch_id, stream_name, opts \\ []) when is_binary(stream_name) and (is_reference(batch_id) or batch_id == :new) do
    _default_write_opts = [
      expect: :any,
      raw?: false,
      stream: stream_name
    ]

    # TODO
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
  `Spear.Records.Streams.read_resp/0` records will be returned in the shape of

  ```elixir
  {subscription :: reference(), Spear.Records.Streams.read_resp()}
  ```

  This function will block the caller until the subscription has been
  confirmed by the EventStoreDB.

  When the subscription is terminated, the subscription process will receive a
  message in the form of `{:eos, subscription, reason}`. `{:eos, subscription,
  :closed}` is emitted when the connection between EventStoreDB and subscriber
  is severed and `{:eos, subscription, :dropped}` is emitted when the
  EventStoreDB explicitly drops a subscription. If this message is received,
  the subscription is considered to be concluded and the subscription process
  must re-subscribe from the last received event or checkpoint to resume
  the subscription. `subscription` is the reference returned by this function.

  Events can be correlated to their subscription via the `subscription`
  reference returned by this function. The subscription reference is included
  in `Spear.Event.metadata.subscription`,
  `Spear.Filter.Checkpoint.subscription`, and in the
  `{:eos, subscription, reason}` tuples as noted above.

  Subscriptions can be gracefully shut down with `Spear.cancel_subscription/3`.
  The subscription will be cancelled by the connection process if the
  subscriber process exits.

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
      {:eos, #Reference<0.1160763861.3015180291.51238>, :closed}
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
      through: &Spear.Reading.decode_read_response/2,
      credentials: nil
    ]

    opts =
      default_subscribe_opts
      |> Keyword.merge(opts)
      |> Keyword.merge(stream: stream_name, subscriber: subscriber)

    through =
      if opts[:raw?] do
        fn resp, subscription -> {subscription, resp} end
      else
        opts[:through]
      end

    request = opts |> Enum.into(%{}) |> Spear.Reading.build_subscribe_request()

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
  @doc api: :utils
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

    rpc = if opts[:tombstone?], do: :Tombstone, else: :Delete

    messages = [Spear.Writing.build_delete_request(opts |> Enum.into(%{}))]

    request_opts = Keyword.take(opts, [:credentials, :timeout])

    with {:ok, _response} <- request(conn, Streams, rpc, messages, request_opts) do
      :ok
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

  This function appends metadata to the `$streams` EventStoreDB stream
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
    |> Spear.append(conn, "$$$streams", opts)
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
          connection :: Spear.Connection.t(),
          full_name :: String.t(),
          login_name :: String.t(),
          password :: String.t(),
          groups :: [String.t()],
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def create_user(conn, full_name, login_name, password, groups, opts \\ []) do
    message =
      Users.create_req(
        options:
          Users.create_req_options(
            full_name: full_name,
            login_name: login_name,
            password: password,
            groups: groups
          )
      )

    with {:ok, Users.create_resp()} <- request(conn, Users, :Create, [message], opts) do
      :ok
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
          connection :: Spear.Connection.t(),
          full_name :: String.t(),
          login_name :: String.t(),
          password :: String.t(),
          groups :: [String.t()],
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def update_user(conn, full_name, login_name, password, groups, opts \\ []) do
    message =
      Users.update_req(
        options:
          Users.update_req_options(
            full_name: full_name,
            login_name: login_name,
            password: password,
            groups: groups
          )
      )

    with {:ok, Users.update_resp()} <- request(conn, Users, :Update, [message], opts) do
      :ok
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
  @spec delete_user(
          connection :: Spear.Connection.t(),
          login_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def delete_user(conn, login_name, opts \\ []) do
    message = Users.delete_req(options: Users.delete_req_options(login_name: login_name))

    with {:ok, Users.delete_resp()} <- request(conn, Users, :Delete, [message], opts) do
      :ok
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
  @spec enable_user(
          connection :: Spear.Connection.t(),
          login_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def enable_user(conn, login_name, opts \\ []) do
    message = Users.enable_req(options: Users.enable_req_options(login_name: login_name))

    with {:ok, Users.enable_resp()} <- request(conn, Users, :Enable, [message], opts) do
      :ok
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
  @spec disable_user(
          connection :: Spear.Connection.t(),
          login_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def disable_user(conn, login_name, opts \\ []) do
    message = Users.disable_req(options: Users.disable_req_options(login_name: login_name))

    with {:ok, Users.disable_resp()} <- request(conn, Users, :Disable, [message], opts) do
      :ok
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
  @spec user_details(
          connection :: Spear.Connection.t(),
          login_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def user_details(conn, login_name, opts \\ []) do
    message = Users.details_req(options: Users.details_req_options(login_name: login_name))

    with {:ok, detail_stream} <- request(conn, Users, :Details, [message], opts) do
      details =
        detail_stream
        |> Enum.take(1)
        |> List.first()
        |> Spear.User.from_details_resp()

      {:ok, details}
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
  @spec change_user_password(
          connection :: Spear.Connection.t(),
          login_name :: String.t(),
          current_password :: String.t(),
          new_password :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def change_user_password(conn, login_name, current_password, new_password, opts \\ []) do
    message =
      Users.change_password_req(
        options:
          Users.change_password_req_options(
            login_name: login_name,
            current_password: current_password,
            new_password: new_password
          )
      )

    with {:ok, Users.change_password_resp()} <-
           request(conn, Users, :ChangePassword, [message], opts) do
      :ok
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
  @spec reset_user_password(
          connection :: Spear.Connection.t(),
          login_name :: String.t(),
          new_password :: String.t(),
          opts :: Keyword.t()
        ) ::
          :ok | {:error, any()}
  def reset_user_password(conn, login_name, new_password, opts \\ []) do
    message =
      Users.reset_password_req(
        options:
          Users.reset_password_req_options(
            login_name: login_name,
            new_password: new_password
          )
      )

    with {:ok, Users.reset_password_resp()} <-
           request(conn, Users, :ResetPassword, [message], opts) do
      :ok
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
  @spec request(
          connection :: Spear.Connection.t(),
          api :: module(),
          rpc :: atom(),
          messages :: Enumerable.t(),
          opts :: Keyword.t()
        ) ::
          {:ok, tuple() | Enumerable.t()} | {:error, any()}
  def request(conn, api, rpc, messages, opts \\ []) do
    opts =
      [
        timeout: 5_000,
        credentials: nil,
        raw?: false
      ]
      |> Keyword.merge(opts)

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
           Spear.Grpc.Response.from_connection_response(response, request.rpc, opts[:raw?]) do
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
  @spec parse_stamp(stamp :: pos_integer()) :: {:ok, DateTime.t()} | {:error, atom()}
  def parse_stamp(ticks_since_epoch) when is_integer(ticks_since_epoch) do
    ticks_since_epoch
    |> div(10)
    |> DateTime.from_unix(:microsecond)
  end

  @doc """
  Requests that a scavenge be started

  Scavenges are disk-space reclaiming operations run on the EventStoreDB
  server.

  ## Options

  * `:thread_count` - (default: `1`) the number of threads to use for the
    scavenge process. Scavenging can be resource intensive. Setting this to
    a low thread count can lower the impact on the server's resources.
  * `:start_from_chunk` - (default: `0`) the chunk number to start the
    scavenge from. Generally this is only useful if a prior scavenge has
    failed on a certain chunk.

  Remaining options are passed to `request/5`.

  ## Examples

      iex> Spear.start_scavenge(conn)
      {:ok,
       %Spear.Scavenge{id: "d2897ba8-2f0c-4fc4-bb25-798ba75f3562", result: :Started}}
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec start_scavenge(connection :: Spear.Connection.t(), opts :: Keyword.t()) ::
          {:ok, Spear.Scavenge.t()} | {:error, any()}
  def start_scavenge(conn, opts \\ []) do
    opts =
      [
        thread_count: 1,
        start_from_chunk: 0
      ]
      |> Keyword.merge(opts)

    message =
      Operations.start_scavenge_req(
        options:
          Operations.start_scavenge_req_options(
            thread_count: opts[:thread_count],
            start_from_chunk: opts[:start_from_chunk]
          )
      )

    with {:ok, Operations.scavenge_resp() = resp} <-
           request(
             conn,
             Operations,
             :StartScavenge,
             [message],
             Keyword.take(opts, [:timeout, :credentials])
           ) do
      {:ok, Spear.Scavenge.from_scavenge_resp(resp)}
    end
  end

  @doc """
  Produces the scavenge stream for a scavenge ID

  `start_scavenge/2` begins an asynchronous scavenge operation since scavenges
  may be time consuming. In order to check the progress of a running scavenge,
  one may read the scavenge stream with `read_stream/3` or `stream!/3` or
  subscribe to updates on the scavenge with `subscribe/4`.

  ## Examples

      iex> {:ok, scavenge} = Spear.start_scavenge(conn)
      {:ok,
       %Spear.Scavenge{id: "d2897ba8-2f0c-4fc4-bb25-798ba75f3562", result: :Started}}
      iex> Spear.scavenge_stream(scavenge)
      "$scavenges-d2897ba8-2f0c-4fc4-bb25-798ba75f3562"
  """
  @doc since: "0.4.0"
  @doc api: :utils
  @spec scavenge_stream(scavenge :: String.t() | Spear.Scavenge.t()) :: String.t()
  def scavenge_stream(%Spear.Scavenge{id: scavenge_id}), do: scavenge_stream(scavenge_id)
  def scavenge_stream(scavenge_id) when is_binary(scavenge_id), do: "$scavenges-" <> scavenge_id

  @doc """
  Stops a running scavenge

  ## Options

  All options are passed to `request/5`.

  ## Examples

      iex> {:ok, scavenge} = Spear.start_scavenge(conn)
      iex> Spear.stop_scavenge(conn, scavenge.id)
      {:ok,
       %Spear.Scavenge{id: "d2897ba8-2f0c-4fc4-bb25-798ba75f3562", result: :Stopped}}
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec stop_scavenge(
          connection :: Spear.Connection.t(),
          scavenge_id :: String.t(),
          opts :: Keyword.t()
        ) :: {:ok, Spear.Scavenge.t()} | {:error, any()}
  def stop_scavenge(conn, scavenge_id, opts \\ [])

  def stop_scavenge(conn, scavenge_id, opts) when is_binary(scavenge_id) do
    message =
      Operations.stop_scavenge_req(
        options: Operations.stop_scavenge_req_options(scavenge_id: scavenge_id)
      )

    with {:ok, Operations.scavenge_resp() = resp} <-
           request(conn, Operations, :StopScavenge, [message], opts) do
      # coveralls-ignore-start
      {:ok, Spear.Scavenge.from_scavenge_resp(resp)}
      # coveralls-ignore-stop
    end
  end

  @doc """
  Shuts down the connected EventStoreDB

  The user performing the shutdown (either the connection credentials or
  credentials passed by the `:credentials` option) must at least be in the
  `$ops` group. `$admins` permissions are a superset of `$ops`.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.shutdown(conn)
      :ok
      iex> Spear.ping(conn)
      {:error, :closed}

      iex> Spear.shutdown(conn, credentials: {"some_non_ops_user", "changeit"})
      {:error,
       %Spear.Grpc.Response{
         data: "",
         message: "Access Denied",
         status: :permission_denied,
         status_code: 7
       }}
      iex> Spear.ping(conn)
      :pong
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec shutdown(connection :: Spear.Connection.t(), opts :: Keyword.t()) :: :ok | {:error, any()}
  def shutdown(conn, opts \\ []) do
    with {:ok, empty()} <- request(conn, Operations, :Shutdown, [empty()], opts) do
      :ok
    end
  end

  @doc """
  Requests that the indices be merged

  <!--
  YARD I have no idea what this does
  -->

  See the EventStoreDB documentation for more information.

  A user does not need to be in `$ops` or any group to initiate this request.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.merge_indexes(conn)
      :ok
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec merge_indexes(connection :: Spear.Connection.t(), opts :: Keyword.t()) ::
          :ok | {:error, any()}
  def merge_indexes(conn, opts \\ []) do
    # coveralls-ignore-start
    with {:ok, empty()} <- request(conn, Operations, :MergeIndexes, [empty()], opts) do
      :ok
    end
  end

  @doc """
  Requests that the currently connected node resign its leadership role

  <!--
  YARD I have no idea what this does
  -->

  See the EventStoreDB documentation for more information.

  A user does not need to be in `$ops` or any group to initiate this request.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.resign_node(conn)
      :ok
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec resign_node(connection :: Spear.Connection.t(), opts :: Keyword.t()) ::
          :ok | {:error, any()}
  def resign_node(conn, opts \\ []) do
    # coveralls-ignore-start
    with {:ok, empty()} <- request(conn, Operations, :ResignNode, [empty()], opts) do
      :ok
    end
  end

  @doc """
  Sets the node priority number

  <!--
  YARD I have no idea what this does
  -->

  See the EventStoreDB documentation for more information.

  A user does not need to be in `$ops` or any group to initiate this request.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.set_node_priority(conn, 1)
      :ok
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec set_node_priority(
          connection :: Spear.Connection.t(),
          priority :: integer(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  # coveralls-ignore-start
  def set_node_priority(conn, priority, opts \\ [])

  def set_node_priority(conn, priority, opts) when is_integer(priority) do
    message = Operations.set_node_priority_req(priority: priority)

    with {:ok, empty()} <- request(conn, Operations, :SetNodePriority, [message], opts) do
      :ok
    end
  end

  @doc """
  Restarts all persistent subscriptions

  See the EventStoreDB documentation for more information.

  A user does not need to be in `$ops` or any group to initiate this request.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.restart_persistent_subscriptions(conn)
      :ok
  """
  @doc since: "0.4.0"
  @doc api: :operations
  @spec restart_persistent_subscriptions(connection :: Spear.Connection.t(), opts :: Keyword.t()) ::
          :ok | {:error, any()}
  def restart_persistent_subscriptions(conn, opts \\ []) do
    # coveralls-ignore-start
    with {:ok, empty()} <-
           request(conn, Operations, :RestartPersistentSubscriptions, [empty()], opts) do
      :ok
    end
  end

  @doc """
  Reads the cluster information from the connected EventStoreDB

  Returns a list of members which are clustered to the currently connected
  EventStoreDB.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.cluster_info(conn)
      {:ok,
       [
         %Spear.ClusterMember{
           address: "127.0.0.1",
           alive?: true,
           instance_id: "eba4c27f-e443-4b21-8756-00845bc5cda1",
           port: 2113,
           state: :Leader,
           timestamp: ~U[2021-04-19 17:25:17.875824Z]
         }
       ]}
  """
  @doc since: "0.5.0"
  @doc api: :gossip
  @spec cluster_info(connection :: Spear.Connection.t(), opts :: Keyword.t()) ::
          {:ok, [Spear.ClusterMember.t()]} | {:error, any()}
  def cluster_info(conn, opts \\ []) do
    with {:ok, Gossip.cluster_info(members: members)} <-
           request(conn, Gossip, :Read, [empty()], opts) do
      {:ok, Enum.map(members, &Spear.ClusterMember.from_member_info/1)}
    end
  end

  @doc """
  Deletes a persistent subscription from the EventStoreDB

  Persistent subscriptions are considered unique by their stream and group
  names together: you may define separate persistent subscriptions for the same
  stream with multiple groups or use the same group name for persistent
  subscriptions to multiple streams. A combination of stream name and group
  name together is considered unique though.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.delete_persistent_subscription(conn, "my_stream", "MyGroup")
      :ok
  """
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec delete_persistent_subscription(
          connection :: Spear.Connection.t(),
          stream_name :: String.t(),
          group_name :: String.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def delete_persistent_subscription(conn, stream_name, group_name, opts \\ [])

  def delete_persistent_subscription(conn, stream_name, group_name, opts)
      when (is_binary(stream_name) or stream_name == :all) and is_binary(group_name) do
    message =
      Persistent.delete_req(
        options:
          Persistent.delete_req_options(
            stream_option: Spear.PersistentSubscription.map_short_stream_option(stream_name),
            group_name: group_name
          )
      )

    with {:ok, Persistent.delete_resp()} <- request(conn, Persistent, :Delete, [message], opts) do
      :ok
    end
  end

  @doc """
  Creates a persistent subscription

  See `t:Spear.PersistentSubscription.Settings.t/0` for more information.

  Note that persistent subscriptions to the `:all` stream with server-side
  filtering is a feature introduced in EventStoreDB v21.6.0. Attempting
  to use the `:all` stream on older EventStoreDB versions will fail.

  ## Options

  * `:from` - the position or revision in the stream where the persistent
    subscription should start. This option may be `:start` or `:end`
    describing the beginning or end of the stream. When the `stream_name`
    is `:all`, this paramater describes the prepare and commit positions
    in the `:all` stream which can be found on any event emitted from a
    subscription to the `:all` stream. When the `stream_name` is not the
    `:all` stream, this option may be an integer representing the event
    number in the stream from which the subscription should start. This
    may be found on any `t:Spear.Event.t/0`. This option may be passed
    a `t:Spear.Event.t/0`, from which either the revision or position will
    be determined based on the stream name. This option overwrites the
    `:revision` field on the `t:Spear.PersistentSubscription.Settings.t/0`
    type which is now deprecated.

  * `:filter` - a filter to apply while reading from the `:all` stream.
    This option only applies when reading the `:all` stream. The same
    data structure works for regular and persistent subscriptions to
    the `:all` stream. See the `t:Spear.Filter.t/0` documentation for
    more information.

  Remaining options are passed to `request/5`.

  ## Examples

      iex> Spear.create_persistent_subscription(conn, "my_stream", "my_group", %Spear.PersistentSubscription.Settings{})
      :ok
      iex> import Spear.Filter
      iex> filter = ~f/My.Aggregate.A- My.Aggregate.B-/ps
      iex> Spear.create_persistent_subscription(conn, :all, "my_all_group", %Spear.PersistentSubscription.Settings{}, filter: filter)
      :ok
  """
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec create_persistent_subscription(
          connection :: Spear.Connection.t(),
          stream_name :: String.t() | :all,
          group_name :: String.t(),
          settings :: Spear.PersistentSubscription.Settings.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def create_persistent_subscription(conn, stream_name, group_name, settings, opts \\ [])

  def create_persistent_subscription(
        conn,
        stream_name,
        group_name,
        %Spear.PersistentSubscription.Settings{} = settings,
        opts
      )
      when (is_binary(stream_name) or stream_name == :all) and is_binary(group_name) do
    message =
      Spear.PersistentSubscription.build_create_request(stream_name, group_name, settings, opts)

    with {:ok, Persistent.create_resp()} <- request(conn, Persistent, :Create, [message], opts) do
      :ok
    end
  end

  @doc """
  Updates an existing persistent subscription

  See `t:Spear.PersistentSubscription.Settings.t/0` for more information.

  Note that persistent subscriptions to the `:all` stream with server-side
  filtering is a feature introduced in EventStoreDB v21.6.0. Attempting
  to use the `:all` stream on older EventStoreDB versions will fail.

  ## Options

  Options are passed to `request/5`.

  ## Examples

      iex> Spear.update_persistent_subscription(conn, "my_stream", "my_group", %Spear.PersistentSubscription.Settings{})
      :ok
  """
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec update_persistent_subscription(
          connection :: Spear.Connection.t(),
          stream_name :: String.t(),
          group_name :: String.t(),
          settings :: Spear.PersistentSubscription.Settings.t(),
          opts :: Keyword.t()
        ) :: :ok | {:error, any()}
  def update_persistent_subscription(conn, stream_name, group_name, settings, opts \\ [])

  def update_persistent_subscription(
        conn,
        stream_name,
        group_name,
        %Spear.PersistentSubscription.Settings{} = settings,
        opts
      )
      when (is_binary(stream_name) or stream_name == :all) and is_binary(group_name) do
    message =
      Persistent.update_req(
        options:
          Persistent.update_req_options(
            stream_identifier: Shared.stream_identifier(stream_name: stream_name),
            stream_option:
              Spear.PersistentSubscription.map_update_stream_option(stream_name, opts),
            group_name: group_name,
            settings: Spear.PersistentSubscription.Settings.to_record(settings, :update)
          )
      )

    with {:ok, Persistent.update_resp()} <- request(conn, Persistent, :Update, [message], opts) do
      :ok
    end
  end

  @doc """
  Lists the currently existing persistent subscriptions

  Results are returned in an `t:Enumerable.t/0` of
  `t:Spear.PersistentSubscription.t/0`.

  Note that the `:extra_statistics?` field of settings is not determined by
  this function: `:extra_statistics?` will always be returned as `nil` in this
  function.

  This function works by reading the built-in `$persistentSubscriptionConfig`
  stream. This stream can be read normally to obtain additional information
  such as at timestamp for the last time the persistent subscription config was
  updated.

  ## Options

  Options are passed to `read_stream/3`. `:direction`, `:from`, and
  `:max_count` are fixed and cannot be overridden.

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
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec list_persistent_subscriptions(connection :: Spear.Connection.t(), opts :: Keyword.t()) ::
          {:ok, Enumerable.t()} | {:error, any()}
  def list_persistent_subscriptions(conn, opts \\ []) do
    read_opts =
      opts
      |> Keyword.merge(
        direction: :backwards,
        from: :end,
        max_count: 1
      )

    with {:ok, stream} <- read_stream(conn, "$persistentSubscriptionConfig", read_opts) do
      subscriptions =
        stream
        |> Stream.flat_map(&get_in(&1, [Access.key(:body), "entries"]))
        |> Stream.map(&Spear.PersistentSubscription.from_map/1)

      {:ok, subscriptions}
    end
  end

  @doc """
  Subscribes a process to an existing persistent subscription

  Persistent subscriptions can be gracefully closed with
  `cancel_subscription/3` just like subscriptions started with `subscribe/4`.
  The subscription will be cancelled by the connection process if the
  subscriber process exits.

  Persistent subscriptions are an alternative to standard subscriptions
  (via `subscribe/4`) which use `ack/3` and `nack/4` to exert backpressure
  and allow out-of-order and batch processing within a single consumer
  and allow multiple connected consumers at once.

  In standard subscriptions (via `subscribe/4`), if a client wishes to
  handle events in order without reprocessing, the client must keep track
  of its own position in a stream, either in memory or using some sort of
  persistence such as PostgreSQL or mnesia for durability.

  In contrast, persistent subscriptions are stateful on the server-side:
  the EventStoreDB will keep track of which events have been positively and
  negatively acknowledged and will only emit events which have not yet
  been processed to any connected consumers.

  This allows one to connect multiple subscriber processes to a persistent
  subscription stream-group combination in a strategy called [Competing
  Consumers](https://docs.microsoft.com/en-us/azure/architecture/patterns/competing-consumers).

  Note that persistent subscription events are not guaranteed to be processed
  in order like the standard subscriptions because of the ability to `nack/4`
  and reprocess or park a message. While this requires special considerations
  when authoring a consumer, it allows one to easily write a consumer which
  does not head-of-line block in failure cases.

  The subscriber will receive a message `{:eos, subscription, reason}` when the
  subscription is closed by the server. `:closed` denotes that the EventStoreDB
  connection has been severed and `:dropped` denotes that the EventStoreDB
  has explicitly told the subscriber that the subscription is terminated.
  This can occur for persistent subscriptions in the case where the
  subscription is deleted (e.g. via `Spear.delete_persistent_subscription/4`).
  `subscription` is the reference retuned by this function.

  ```elixir
  iex> Spear.create_persistent_subscription(conn, "asdf", "asdf", %Spear.PersistentSubscription.Settings{})
  :ok
  iex> Spear.connect_to_persistent_subscription(conn, self(), "asdf", "asdf")
  {:ok, #Reference<0.515780924.2297430020.166204>}
  iex> flush
  :ok
  iex> Spear.delete_persistent_subscription(conn, "asdf", "asdf")
  :ok
  iex> flush
  {:eos, #Reference<0.515780924.2297430020.166204>, :dropped}
  :ok
  ```

  Like subscriptions from `subscribe/4`, events can be correlated to their
  subscription by the `:subscription` key in each `Spear.Event.metadata`
  map.

  Note that persistent subscriptions to the `:all` stream with server-side
  filtering is a feature introduced in EventStoreDB v21.6.0. Attempting
  to use the `:all` stream on older EventStoreDB versions will fail.

  ## Backpressure

  Persistent subscriptions allow the subscriber process to exert backpressure
  on the EventStoreDB so that the message queue is not flooded. This is
  implemented with a buffer of events which are considered by the EventStoreDB
  to be _in-flight_ when they are sent to the client. Events remain in-flight
  until they are `ack/3`-ed, `nack/4`-ed, or until the `:message_timeout`
  duration is exceeded. If a client `ack/3`s a message, the EventStoreDB
  will send a new message if any are available.

  The in-flight buffer size is controllable per subscriber through
  `:buffer_size`. Note that `:message_timeout` applies to each event: if
  the `:buffer_size` is 5 and five events arrive simultaneously, the client
  has the duration `:message_timeout` to acknowledge all five events before
  they are considered stale and are automatically considered nack-ed by
  the EventStoreDB.

  The `:buffer_size` should align with the consumer's ability to batch
  process events.

  ## Options

  * `:timeout` - (default: `5_000`ms - 5s) the time to await a subscription
    confirmation from the EventStoreDB.
  * `:raw?` - (default: `false`) controls whether events are translated from
    low-level `Spear.Records.Persistent.read_resp/0` records to
    `t:Spear.Event.t/0`s. By default `t:Spear.Event.t/0`s are sent to the
    subscriber.
  * `:credentials` - (default: `nil`) the credentials to use to connect to the
    subscription. When not specified, the connection-level credentials are
    used. Credentials must be a two-tuple `{username, password}`.
  * `:buffer_size` - (default: `1`) the number of events allowed to be sent
    to the client at a time. These events are considered in-flight. See the
    backpressure section above for more information.

  ## Examples

      iex> Spear.connect_to_persistent_subscription(conn, self(), "my_stream", "my_group")
      iex> flush
      %Spear.Event{}
      :ok
  """
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec connect_to_persistent_subscription(
          connection :: Spear.Connection.t(),
          subscriber :: pid() | GenServer.name(),
          stream_name :: String.t() | :all,
          group_name :: String.t(),
          opts :: Keyword.t()
        ) :: {:ok, subscription :: reference()} | {:error, any()}
  def connect_to_persistent_subscription(conn, subscriber, stream_name, group_name, opts \\ [])

  def connect_to_persistent_subscription(conn, subscriber, stream_name, group_name, opts)
      when (is_binary(stream_name) or stream_name == :all) and is_binary(group_name) do
    default_subscribe_opts = [
      timeout: 5_000,
      raw?: false,
      through: &Spear.Reading.decode_read_response/2,
      credentials: nil,
      buffer_size: 1
    ]

    opts =
      default_subscribe_opts
      |> Keyword.merge(opts)
      |> Keyword.merge(stream: stream_name, subscriber: subscriber)

    message =
      Persistent.read_req(
        content:
          {:options,
           Persistent.read_req_options(
             stream_option: Spear.PersistentSubscription.map_short_stream_option(stream_name),
             group_name: group_name,
             buffer_size: opts[:buffer_size],
             uuid_option: Persistent.read_req_options_uuid_option(content: {:string, empty()})
           )}
      )

    through =
      if opts[:raw?] do
        # coveralls-ignore-start
        fn resp, subscription -> {subscription, resp} end
        # coveralls-ignore-stop
      else
        opts[:through]
      end

    request =
      %Spear.Request{
        api: {Persistent, :Read},
        messages: [message],
        credentials: opts[:credentials]
      }
      |> Spear.Request.expand()

    call = {{:subscription, subscriber, through}, request}

    case Connection.call(conn, call, opts[:timeout]) do
      {:ok, subscription} when is_reference(subscription) ->
        {:ok, subscription}

      {:ok, %Spear.Connection.Response{} = response} ->
        grpc_response =
          Spear.Grpc.Response.from_connection_response(response, request.rpc, opts[:raw?])

        {:error, grpc_response}

      # coveralls-ignore-start
      error ->
        error

        # coveralls-ignore-stop
    end
  end

  @doc """
  Acknowledges that an event received as part of a persistent subscription was
  successfully handled

  Although `ack/3` can accept a `t:Spear.Event.t/0` alone, the underlying
  gRPC call acknowledges a batch of event IDs.

  ```elixir
  Spear.ack(conn, subscription, events |> Enum.map(&Spear.Event.id/1))
  ```

  should be preferred over

  ```elixir
  Enum.each(events, &Spear.ack(conn, subscription, Spear.Event.id(&1)))
  ```

  As the acknowledgements will be batched.

  This function (and `nack/4`) are asynchronous casts to the connection
  process.

  ## Examples

      # some stream with 3 events
      stream_name = "my_stream"
      group_name = "spear_iex"
      settings = %Spear.PersistentSubscription.Settings{}

      get_event_and_ack = fn conn, sub ->
        receive do
          %Spear.Event{} = event ->
            :ok = Spear.ack(conn, sub, event)

            event

        after
          3_000 -> :no_events
        end
      end

      iex> Spear.create_persistent_subscription(conn, stream_name, group_name, settings)
      :ok
      iex> {:ok, sub} = Spear.connect_to_persistent_subscription(conn, self(), stream_name, group_name)
      iex> get_event_and_ack.(conn, sub)
      %Spear.Event{..}
      iex> get_event_and_ack.(conn, sub)
      %Spear.Event{..}
      iex> get_event_and_ack.(conn, sub)
      %Spear.Event{..}
      iex> get_event_and_ack.(conn, sub)
      :no_events
      iex> Spear.cancel_subscription(conn, sub)
      :ok
  """
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec ack(
          connection :: Spear.Connection.t(),
          subscription :: reference(),
          event_or_ids :: Spear.Event.t() | [String.t()]
        ) :: :ok
  def ack(conn, subscription, event_or_ids)

  def ack(conn, sub, %Spear.Event{} = event), do: ack(conn, sub, [Spear.Event.id(event)])

  def ack(conn, sub, event_ids) when is_list(event_ids) do
    id = ""
    ids = Enum.map(event_ids, fn id -> Shared.uuid(value: {:string, id}) end)
    message = Persistent.read_req(content: {:ack, Persistent.read_req_ack(id: id, ids: ids)})

    Connection.cast(conn, {:push, sub, message})
  end

  @doc """
  Negatively acknowldeges a persistent subscription event

  Nacking is the opposite of `ack/3`ing: it tells the EventStoreDB that the
  event should not be considered processed.

  ## Options

  * `:action` - (default: `:retry`) controls the action the EventStoreDB
    should take about the event. See
    `t:Spear.PersistentSubscription.nack_action/0` for a full description.
  * `:reason` - (default: `""`) a description of why the event is
    being nacked

  ## Examples

      # some stream with 3 events
      stream_name = "my_stream"
      group_name = "spear_iex"
      settings = %Spear.PersistentSubscription.Settings{}

      get_event_and_ack = fn conn, sub, action ->
        receive do
          %Spear.Event{} = event ->
            :ok = Spear.nack(conn, sub, event, action: action)

            event

        after
          3_000 -> :no_events
        end
      end

      iex> Spear.create_persistent_subscription(conn, stream_name, group_name, settings)
      :ok
      iex> {:ok, sub} = Spear.connect_to_persistent_subscription(conn, self(), stream_name, group_name)
      iex> get_event_and_nack.(conn, sub, :retry)
      %Spear.Event{..} # event 0
      iex> get_event_and_nack.(conn, sub, :retry)
      %Spear.Event{..} # event 0
      iex> get_event_and_nack.(conn, sub, :park) # park event 0 and move on
      %Spear.Event{..} # event 0
      iex> get_event_and_nack.(conn, sub, :skip) # skip event 1
      %Spear.Event{..} # event 1
      iex> get_event_and_nack.(conn, sub, :skip) # skip event 2
      %Spear.Event{..} # event 2
      iex> get_event_and_nack.(conn, sub, :skip)
      :no_events
      iex> Spear.cancel_subscription(conn, sub)
      :ok
  """
  @doc since: "0.6.0"
  @doc api: :persistent
  @spec nack(
          connection :: Spear.Connection.t(),
          subscription :: reference(),
          event_or_ids :: Spear.Event.t() | [String.t()],
          opts :: Keyword.t()
        ) :: :ok
  # coveralls-ignore-start
  def nack(conn, subscription, event_or_ids, opts \\ [])
  # coveralls-ignore-stop

  def nack(conn, sub, %Spear.Event{} = event, opts),
    do: nack(conn, sub, [Spear.Event.id(event)], opts)

  def nack(conn, sub, event_ids, opts) when is_list(event_ids) do
    reason = Keyword.get(opts, :reason, "")
    action = Keyword.get(opts, :action, :retry)

    id = ""
    ids = Enum.map(event_ids, fn id -> Shared.uuid(value: {:string, id}) end)

    message =
      Persistent.read_req(
        content:
          {:nack,
           Persistent.read_req_nack(
             id: id,
             ids: ids,
             action: Spear.PersistentSubscription.map_nack_action(action),
             reason: reason
           )}
      )

    Connection.cast(conn, {:push, sub, message})
  end

  @doc """
  Returns the parked events stream for a persistent subscription stream and
  group.

  If an event is negatively acknowledged and parked, the persistent subscription
  will add it to the park stream for the given stream+group combination. It
  can be useful to read this stream to determine if there are any parked
  messages.

  ## Examples

      iex> Spear.park_stream("MyStream", "MyGroup")
      "$persistentsubscription-MyStream::MyGroup-parked"
  """
  @doc since: "0.9.1"
  @doc api: :utils
  @spec park_stream(stream_name :: String.t(), group_name :: String.t()) :: String.t()
  def park_stream(stream_name, group_name)
      when is_binary(stream_name) and is_binary(group_name) do
    "$persistentsubscription-#{stream_name}::#{group_name}-parked"
  end

  @doc """
  Subscribes a process to stats updates from the EventStoreDB

  This function subscribes a process in the same way as `subscribe/4`: the
  function will return a reference representing the subscription and the
  stats messages will be sent to the subscriber process with `send/2`.

  This subscription can be cancelled with `cancel_subscription/3`.

  This functionality was added to EventStoreDB in release v21.6.0. Prior
  EventStoreDB versions will throw a GRPC error when attempting to use
  this function.

  ## Options

  * `:interval` - (default: `5_000` - 5 seconds) the interval after which
    a new stats message should be sent. By default, stats messages arrive
    every five seconds.
  * `:use_metadata?` - (default: `true`) undocumented option. See the
    EventStoreDB implementation for more information.
  * `:timeout` - (default: `5_000` - 5 seconds) the GenServer timeout to
    use when requesting a subscription to stats
  * `:raw?` - (default: `false`) whether to emit the stats messages as
    'raw' `Spear.Records.Monitoring.stats_resp/0` records in a tuple of
    `{subscription :: reference(), Spear.Records.Monitoring.stats_resp()}`.
    By default, stats messages are returned as maps.
  * `:credentials` - (default: `nil`) credentials to use to perform this
    subscription request.

  ## Examples

      iex> Spear.subscribe_to_stats(conn, self())
      {:ok, #Reference<0.359109646.3547594759.216222>}
      iex> flush()
      %{
        "es-queue-Projection Core #2-length" => "0",
        "es-queue-Worker #1-lengthLifetimePeak" => "0",
        "es-queue-Worker #3-lengthCurrentTryPeak" => "0",
        "es-queue-StorageReaderQueue #9-avgProcessingTime" => "0",
        "es-queue-StorageReaderQueue #6-idleTimePercent" => "100",
        ..
      }
  """
  @doc since: "0.10.0"
  @doc api: :monitoring
  @spec subscribe_to_stats(
          connection :: Spear.Connection.t(),
          subscriber :: pid() | GenServer.name(),
          opts :: Keyword.t()
        ) ::
          {:ok, reference()} | {:error, any()}
  def subscribe_to_stats(conn, subscriber, opts \\ []) do
    default_subscribe_opts = [
      use_metadata?: false,
      interval: 5_000,
      timeout: 5_000,
      raw?: false,
      credentials: nil
    ]

    opts =
      default_subscribe_opts
      |> Keyword.merge(opts)

    stats_req =
      Monitoring.stats_req(
        use_metadata: opts[:use_metadata?],
        refresh_time_period_in_ms: opts[:interval]
      )

    request =
      %Spear.Request{
        api: {Monitoring, :Stats},
        messages: [stats_req],
        credentials: nil
      }
      |> Spear.Request.expand()

    through =
      if opts[:raw?] do
        fn message, request_ref -> {request_ref, message} end
      else
        fn Monitoring.stats_resp(stats: stats), _ -> stats end
      end

    Connection.call(
      conn,
      {{:subscription, subscriber, through}, request},
      opts[:timeout]
    )
  end
end
