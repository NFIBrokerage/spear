# These Protobufs

Last time the protobufs were copied from the upstream:

```
EventStore/EventStore@668a98b43c5b3d0d045c3ee4019c156ec4cae829
```

## How to go get the protobufs

1. Clone the `git@github.com:EventStore/EventStore.git` repository
1. Remove all protos currently in this directory: `rm *.proto`
1. Copy all protos from the EventStore repo
    ```
    cp path/to/EventStore/src/EventStore/src/Protos/Grpc/*.proto .
    ```
1. Remove any cluster protobuf definitions, leaving only client protos and google data-structures
    ```
    grep -l 'package event_store\.cluster' *.proto | xargs rm
    ```

## How to generate the erl/hrl files from these protobufs

1. Get deps for this repo: `mix deps.get`
1. Run the following from the root of this repo:
    ```
    mkdir -p src/
    ./deps/gpb/bin/protoc-erl -strbin -I priv/protos/ -pkgs priv/protos/shared.proto -o src -modprefix 'spear_proto_' priv/protos/*.proto
    ```
1. Now switch all includes for `gpb.hrl` to library includes. With [`fastmod`](https://github.com/facebookincubator/fastmod) this can be done like so. `sed` may also be used, or manual operation.
    ```
    fastmod --fixed-strings --accept-all --print-changed-files 'include_lib("gpb/include/gpb.hrl")' 'include_lib("gpb/include/gpb.hrl")'
    ```

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
