# Writing Events

This guide covers specifics about the `Spear.append/4` function and general
information about the event-writing functionality.

## Enumeration Characteristics

`event_stream` is an `t:Enumerable.t()` which will be lazily computed as
events are emitted over-the-wire to the EventStore via gRPC. The procedure
for emitting events roughly follows this pseudo-code

```elixir
initiate_grpc_request()

event_stream
|> Stream.map(&encode_to_wire_format/1)
|> Enum.each(&emit_event/1)

conclude_grpc_request()
```

This means a few things:

First, you can efficiently emit events from a stream over a large source
such as a large CSV file

```elixir
File.stream!("large.csv", read_ahead: 100_000)
|> MyCsvParser.parse_stream()
|> Stream.map(&MyCsvParser.turn_csv_line_into_spear_event/1)
|> Spear.append(conn, "ChargesFromCsvs", batch_size: 25)
# => :ok
```

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
call to `append/4`. Attempting to write more than the budget will fail
the request with the above signature and no events in the request will be
written to the EventStore. This value is configurable in the EventStoreDB
configuration.
