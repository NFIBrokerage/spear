# Link Resolution

Some functions in Spear have `:resolve_links?` options. Projected streams
such as streams beginning with `"$"` or custom-made projected streams do
not copy event bodies literally from linked events. For example, the `"$all"`
projected stream does not contain a copy of every event in the eventstore.
Rather projected streams are comprised of _link_ events which are very slim
references to the source events. This is conceptually similar to pointers in
a language like C.

When we read a projected stream (in this example an event-type stream) with
`:resolve_links?` set to false, we see

```elixir
iex> import Spear.Records.Streams
iex> alias Spear.Protos.EventStoreDB.Client.Streams.ReadResp
iex> Spear.stream!(conn, "$et-grpc-client", chunk_size: 1, resolve_links?: false, raw?: true) |> Enum.take(1)
[
  read_resp(
    content: {:event,
     read_resp_read_event(
       event: read_resp_read_event_recorded_event(
         data: "0@es_supported_clients"
       ),
       link: :undefined
     )
    )
  )
]
```

(Note that the read-response bodies we see in this section are simplified to
only show the parts interesting to link resolution.)

The `link` field on the read event is `nil` and the `event` field has a
strange `data` body of `0@es_supported_clients`. With link resolution turned
off, we are telling the EventStoreDB that we'd like to read the stream
literally: to receive just the links themselves.

When we turn link resolution on, we see a different picture

```elixir
iex> import Spear.Records.Streams
iex> Spear.stream!(conn, "$et-grpc-client", chunk_size: 1, resolve_links?: true, raw?: true) |> Enum.take(1)
[
  read_resp(
    content: {:event,
     read_resp_read_event(
       event: read_resp_read_event_recorded_event(
         data: "{\"languages\":[\"typescript\",\"javascript\"],\"runtime\":\"NodeJS\"}",
       ),
       link: read_resp_read_event_recorded_event(
         data: "0@es_supported_clients",
       )
     ))
  )
]
```

Now the `:link` field contains the reference to the original event and the
`:event` contains the full data for the original event.

What happens if you try to resolve links for an EventStoreDB stream which is
not a projected stream?

```elixir
iex> import Spear.Records.Streams
iex> Spear.stream!(conn, "es_supported_clients", chunk_size: 1, resolve_links?: true, raw?: true) |> Enum.take(1)
[
  read_resp(
    content: {:event,
     read_resp_read_event(
       event: read_resp_read_event_recorded_event(
         data: "{\"languages\":[\"typescript\",\"javascript\"],\"runtime\":\"NodeJS\"}",
       ),
       link: :undefined
     ))
  )
]
```

Nothing! The events from non-projected streams are unaffected by link
resolution choice. Hence the `:resolve_links?` option is consistently
defaulted to `true`.
