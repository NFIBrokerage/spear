# Writing Events

This guide covers specifics about the `Spear.append/4` function and general
information about the event-writing functionality.

## Enumeration Characteristics

`event_stream` is an `t:Enumerable.t()` which will be lazily written to the
EventStore as elements of the stream are computed and serialized on to the
wire.

This means a few things:

First, you can efficiently emit events from a stream over a large source
such as a CSV file with many lines:

```elixir
File.stream!("large.csv", read_ahead: 100_000)
|> MyCsvParser.parse_stream()
|> Stream.map(&MyCsvParser.turn_csv_line_into_spear_event/1)
|> Spear.append(conn, "ChargesFromCsvs", batch_size: 25)
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
 {:grpc_failure, [code: 3, message: "Maximum Append Size of 1048576 Exceeded."]}}
```

Note that while EventStore streams can in theory store infinitely long
streams, they are not practically able to do so. EventStore limits the size
of a single write to `1_048_576` cumulative bytes. This budget can be spent
on one very large event or, as shown above, many tiny events in a single
call to `Spear.append/4`. Attempting to write more than the budget will fail
the request with the above signature and no events in the request will be
written to the EventStore. This value is configurable in the EventStoreDB
configuration.

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

## Batching

When appending multiple events, Spear will fit as many messages as possible
into the same HTTP2 DATA frame. This is valid according to the gRPC
specification and has the potential to improve performance.
