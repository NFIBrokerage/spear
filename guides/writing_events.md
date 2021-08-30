# Writing Events

This guide covers specifics about the `Spear.append/4` and
`Spear.append_batch/5` functions and general information about the
event-writing functionality.

## Enumeration Characteristics

`event_stream` is an `t:Enumerable.t/0` which will be lazily written to the
EventStoreDB as elements of the stream are computed and serialized on to the
wire.

This means a few things:

First, you can efficiently emit events from a stream over a large source
such as a CSV file with many lines:

```elixir
File.stream!("large.csv", read_ahead: 100_000)
|> MyCsvParser.parse_stream()
|> Stream.map(&MyCsvParser.turn_csv_line_into_spear_event/1)
|> Spear.append(conn, "ChargesFromCsvs", timeout: :infinity)
# => :ok
```

The stream is only fully run after the last bytes have been written to
the gRPC network request: the stream is never computed entirely in memory.

Second, you may (but are _not_ encouraged to) write events via an infinite
stream. A trivial counter mechanism could be implemented like so

```elixir
iex> Stream.iterate(0, &(&1 + 1))
...> |> Stream.map(fn n -> Spear.Event.new("incremented", n) end)
...> |> Spear.append(conn, "InfiniteCounter", timeout: :infinity, expect: :empty)
{:error,
 %Spear.Grpc.Response{
   data: "",
   message: "Maximum Append Size of 1048576 Exceeded.",
   status: :invalid_argument,
   status_code: 3
 }}
```

Note that while EventStoreDB streams can in theory store infinitely long
streams, they are not practically able to do so. EventStoreDB limits the size
of a single write to `1_048_576` cumulative bytes. This budget can be spent
on one very large event or, as shown above, many tiny events in a single
call to `Spear.append/4`. Attempting to write more than the budget will fail
the request with the above signature and no events in the request will be
written to the EventStoreDB. This value is configurable in the EventStoreDB
server configuration.

## Blocking

While `Spear.append/4` blocks the caller for the duration of the request,
it does not fully block the connection. The connection will write chunks of
data over the wire as allowed by HTTP2 window sizes.

HTTP2 includes a back-pressure mechanism for clients sending large amounts
of data to the server faster than the server can handle. Servers negotiate
a maximum number of bytes which the client is allowed to send called a window.
When the window has been exhausted by streaming data to the server, the client
must wait until the server replenishes the window. During the downtime between
exhausting a window and waiting for the server to replenish, Spear suspends
the exhausted request stream and handles incoming messages from the server
as normal. Since HTTP2 window sizes are relatively small (usually somewhere
around the range of 10 and 100 KB), Spear takes conceptual breaks somewhat
often during large requests. This allows Spear to efficiently multiplex large
writes with large reads and subscriptions.

## Increasing append throughput with `Spear.append_batch/5`

EventStoreDB v21.6.0+'s BatchAppend feature is designed to improve performance
of appending large numbers of events. The protobuf and gRPC service definitions
give BatchAppend an advantage over the standard Append RPC both in terms
of encoded message size (and therefore bytes over the network) and number of
HTTP/2 requests.

`Spear.append/4` is a simpler interface for appends and is a reasonable
default. `Spear.append_batch/5` is more cumbersome to use but is also more
powerful. In general, `Spear.append_batch/5` should be preferred when
writing large numbers of events and when append throughput is critical.

## Example: use Streams and Tasks with `Spear.append_batch/5`

Say we have an `t:Enumerable.t/0` of event batches where each element is
a tuple of the stream name to append to and a batch of events to append:
`{stream_name, [%Spear.Event{}, ...]}`. We can use `Task.async_stream/3`
to parallelize appends like so:

```elixir
alias Spear.BatchAppendResult, as: Result

[{stream_name, event_batch}] = Enum.take(event_batch_stream, 1)

{:ok, batch_id, request_id} =
  Spear.append_batch(event_batch, conn, :new, stream_name)

receive(do: (%Result{batch_id: ^batch_id, request_id: ^request_id, result: :ok} -> :ok))
```

We start by opening up a new `Spear.append_batch/5` request using the `:new`
atom as the `request_id` and the first element of the stream as input.

```elixir
event_batch_stream
|> Stream.drop(1)
|> Task.async_stream(fn {stream_name, event_batch} ->
  {:ok, batch_id} =
    Spear.append_batch(event_batch, conn, request_id, stream_name)

  receive do
    %Result{batch_id: ^batch_id, request_id: ^request_id, result: :ok} -> :ok
  end
end)
|> Stream.run()
```

Now we drop the first element of our stream (which we appended to open the
request) and pass the rest of the stream through `Task.async_stream/2`.
`Task.async_stream/2` will apply the anonymous function to each element
of the stream, so we append a batch for each `{stream_name, event_batch}`
element and await the result. `Task.async_stream/2` will spawn processes
for each element, keeping at most `System.schedulers_online/0` processes
running at a time.

Finally we'll close the request using `Spear.cancel_subscription/2`

```elixir
:ok = Spear.cancel_subscription(conn, request_id)
```
