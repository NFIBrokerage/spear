# Streams

Spear uses Elixir `Stream`s consistency across its API but there are many
conceptual meanings of "stream" in the systems which Spear composes.
Consider this call:

```elixir
iex> Spear.stream!(conn, "MyStream", chunk_size: 20) |> Enum.to_list()
[%Spear.Event{}, %Spear.Event{}, ..]
```

This call

- reads an EventStore stream
- over an HTTP2 stream
- which is typed as a gRPC stream response
- and is collected into an Elixir `Stream`

There are four significant concepts for streams in Spear:

- HTTP2 streams of data
- gRPC stream requests, responses, and bidirectional communication
- EventStore streams of events
- Elixir `Stream`s

We'll cover each topic separately to avoid confusion.

#### HTTP2 streams

HTTP2 streams are channels for data and may be multiplexed: multiple requests
may stream data in either direction (client to server or server to client)
at once. HTTP2 streams (and some GenServer tricks) allow Spear to multiplex
requests and subscriptions in a single HTTP2 connection without blocking.
Besides concurrency and blocking concerns, HTTP2 streams are mostly an
implementation detail in Spear.

#### gRPC streams

gRPC allows "unary" request-responses similar to a REST request-response
over HTTP. This resembles synchronous function (or GenServer) calls. The true
power of gRPC, though, comes from its ability to "stream" requests,
responses, or requests and responses simultaneously. Consider this RPC
definition from the EventStore gRPC protobufs:

```protobuf
rpc Read (ReadReq) returns (stream ReadResp);
```

In the `Spear.stream!/3` function, this "stream" response lends itself to
an Elixir `Stream`. Conceptually the `ReadResp` messages are returned as an
ordered list of events in an EventStore stream. These response messages are
returned as quickly as possible and resemble a unary request very closely.

This same RPC is invoked to implement `Spear.subscribe/4`, though, which
does not return an Elixir `t:Enumerable.t/0`. Instead this function
asynchronously signs-up the given process for receiving messages per event.

gRPC streams may emulate synchronous calls returning lists as with
`Spear.stream!/3` but are also commonly used to implement asynchronous
subscription workflows as with `Spear.subscribe/4`.

gRPC streams may even be fully asynchronous is both directions as with
EventStore Persistent Subscriptions. This communication is known as
bidirectional or "bidi-stream" and is covered more fully in the
`Spear.PersistentSubscription` moduledoc.

gRPC streams are also an implementation-level detail in Spear and will
not be mentioned otherwise in this documentation unless specifically called
a "gRPC stream".

#### EventStore streams

EventStore streams are append-only collections of events ordered by the
timestamp of each event's commit (or commit preparation). Streams can be
read forwards or backwards and from any revision (a fancy way of saying
"position in a stream").

EventStore streams will be referred to in this documentation as EventStore
streams, or simply "streams" where contextually appropriate.

#### Elixir Streams

Elixir `Stream`s are conceptually different than both gRPC/HTTP2 streams
and EventStore streams. Elixir `Stream`s differ as well from lazy enumerables
in other languages like Haskell due to the lack of a "thunk" built-in.
`Stream`s are simply formulas for producing enumerable collections such as
`List`s.

Since streams are a formula and not an actual list (or otherwise
collectable), they can exploit some lovely properties:

- computations can be done lazily on demand
    - this can reduce memory consumption
- streams can be composed
- streams can be infinite

A common example is reading a large file such as a big CSV. Without streams,
the entire file must be read into memory and each transformation of each line
or chunk must be computed in entirety before moving on to the next operation
(e.g. with `Enum.map/2` or `Enum.reduce/3`). With a file stream, one may read
a large file line-by-line, perform many `Stream.map/2`s (or similar) and
eventually perform some side-effect by forcing the stream with `Stream.run/1`
or an `Enum` function. Only once the first line or chunk has been read from
the file and run through the pipeline of composed stream functions will the
next one be read and run through.

To differentiate, we will most commonly refer to Elixir `Stream`s in the
Spear documentation by their canonical data-type: `t:Enumerable.t/0`.
