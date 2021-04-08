# These Protobufs

Last time the protobufs were copied from the upstream:

```
EventStore/EventStore@6eedacecd6a4da8ab705a82d5229f5c630f60277
```

## How to generate the Elixir modules from these protobufs

1. Follow the [`elixir-protobuf/protobuf` guide for installing `protoc` and `protoc-gen-elixir`](https://github.com/elixir-protobuf/protobuf#generate-elixir-code)
1. For each `.proto` file in this directory (excluding the google directory), run the following, replacing `<file>` with each file name
    ```
    protoc -I priv/protos --elixir_out=plugins=grpc:./lib/spear/protos priv/protos/<file>
    ```
1. Edit `lib/spear/protos/*.pb.ex` to add the following to the top of the file
    ```
    alias Spear.Protos.EventStore
    ```
1. Also delete all modules with `Stub` in their names
1. Implement the `Spear.TypedMessage` behaviour for all message types ending in `Req` (e.g. `AppendReq`)
    - see [these lines](https://github.com/NFIBrokerage/spear/blob/2811a59050bc3e46cd1ca477eb44b52a1a517aec/lib/spear/protos/streams.pb.ex#L582-L585) for a good example
1. Run `mix format`

## The google proto

See that proto at `priv/protos/google/protobuf/struct.proto`?

It's directly from [this link](https://github.com/protocolbuffers/protobuf/blob/f82e268ed7fc6b34b092349e473d38020cf55928/src/google/protobuf/struct.proto)

`protoc` needs this in order to transpile `priv/protos/projections.proto`,
specifically this line:

```protobuf
import "google/protobuf/struct.proto";
```

I believe everything is squared away license-wise. If not, please open an
issue :)
