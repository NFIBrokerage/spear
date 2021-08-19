# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.10.0 - [UNRELEASED]

### Fixed

- Fixed the `Spear.set_global_acl/4` function to correctly append ACL
  data as an event to the `$streams` metadata stream, instead of to
  the `$streams` stream directly.

## 0.9.1 - 2021-06-01

### Added

- Added `Spear.park_stream/2` to the utilities API

### Fixed

- Removed compilation of mint version in user-agent function
    - This could cause a compilation error when using spear as a transitive
      dependency

## 0.9.0 - 2021-04-29

### Added

- Added a `:link` field to the `t:Spear.Event.t/0` struct
    - this is used to provide accurate stream revisions and IDs in projected
      streams as with `Spear.subscribe/4` or in `Spear.ack/3` or `Spear.nack/4`
- Added `Spear.Event.id/1` and `Spear.Event.revision/1` which take a
  `t:Spear.Event.t/0` and give the ID and revision, respectively
    - these new functions respect the new `:link` field and return link
      information instead of event information if the link is present

### Removed

- Removed link metadata from the `Spear.Event.metadata` map's possible `:link`
  field.
    - use the new top-level `:link` field as `Spear.Event.link.metadata`

Note that this may be a breaking change for any consumers depending on the
optional `:link` field in the metadata packet. Consumers should update by
instead matching on a `t:Spear.Event.t/0` struct in the `:link` field of any
event, or by using the new `Spear.Event.id/1` or `Spear.Event.revision/1`
functions.

## 0.8.1 - 2021-04-27

### Added

- Added the link's stream to the `Spear.Event.metadata.link` field

### Fixed

- Fixed some stray references to structs which should be typed as records
- Fixed `Spear.Event.to_checkpoint/1` to carry over the `:subscription` key
  from a `t:Spear.Event.t/0`'s metadata
- Fixed a bug in `Spear.Connection.Configuration` which would incorrectly
  choose the `:http` scheme when the `:tls?` option was set to `true`

## 0.8.0 - 2021-04-26

### Added

- Added the `:read_only?` configuration flag for
  `Spear.Connection.Configuration`
    - this allows one to limit what the `Spear.Connection` will perform to
      read-only operations such as reading streams
- Added link metadata to the `Spear.Event.metadata` packet in a new `:link`
  field

### Fixed

- Fixed the `:from` option in read requests (`Spear.read_stream/3`,
  `Spear.stream!/3` and `Spear.subscribe/4`) to respect the new link information
  in metadata

## 0.7.0 - 2021-04-24

### Added

- Added the subscription reference returned by `Spear.subscribe/4` and
  `Spear.connect_to_persistent_subscription/5` to
    - the metadata map of `t:Spear.Event.t/0` in the path
      `Spear.Event.metadata.subscription`
    - `t:Spear.Filter.Checkpoint.t/0` in a new field `:subscription`
    - the `:eos` tuples in the new shape of
      `{:eos, reference(), :closed | :dropped}`

Note that this is a breaking change for any consumers matching explicitly
on `:eos` tuples. Consumers relying on the prior data shape should update
like so

```diff
- def handle_info({:eos, reason}, state) do
+ def handle_info({:eos, _subscription, reason}, state) do
```

## 0.6.1 - 2021-04-23

### Fixed

- `Spear.stream!/3` now reads `:from` revisions as inclusive
    - e.g. passing some `event` in the stream to `:from` will ensure that the
      first element in the enumerable is `^event`
    - the same principal applies when passing event revisions
    - see #26
    - if this behavior is undesirable, a Spear user may `Stream.drop/2` the
      initial element in the enumerable
- `Spear.connect_to_persistent_subscription/5` now returns an error tuple
  when attempting to connect to a persistent subscription stream and group
  that has not yet been created.
    - the reason is a `Spear.Grpc.Response` struct with a status of `:not_found`

### Added

- Subscriptions may now emit `{:eos, :dropped}` in cases where the EventStoreDB
  explicitly terminates the subscription
    - this can happen if a persistent subscription is deleted while it has
      subscribers actively connected
    - each subscriber will receive `{:eos, :dropped}` in its mailbox

## 0.6.0 - 2021-04-21

### Added

- Added the CRUD portions of persistent subscriptions API
    - `Spear.create_persistent_subscription/5`
    - `Spear.update_persistent_subscription/5`
    - `Spear.delete_persistent_subscription/4`
    - `Spear.list_persistent_subscriptions/2`
    - associated callbacks in `Spear.Client`
- Added subscription functionality for persistent subscriptions
    - `Spear.connect_to_persistent_subscription/5`
    - `Spear.ack/3`
    - `Spear.nack/4`
    - associated callbacks in `Spear.Client`

### Changed

- Moved `Spear.cancel_subscription/3` under the utils API instead of streams
    - This function may also be used to cancel persistent subscriptions

## 0.5.0 - 2021-04-19

### Added

- Added the gossip API
    - this API is very small: just one function `Spear.cluster_info/2`
    - also added `c:Spear.Client.cluster_info/1`
    - under the hood, this also added the ability to decode structured
      UUIDs received from the EventStoreDB, as are received in the
      `Spear.ClusterMember.instance_id` field. See `Spear.Uuid` for the
      interesting implementation.
    - added the record interface `Spear.Records.Gossip`

### Fixed

- Properly grouped free-floating modules under the proper structures and types
  or record interface groupings in the documentation

## 0.4.0 - 2021-04-19

### Fixed

- Updated security guide to use new configuration style

### Added

- Added the operations API
    - `Spear.merge_indexes/2`
    - `Spear.resign_node/2`
    - `Spear.restart_persistent_subscriptions/2`
    - `Spear.set_node_priority/3`
    - `Spear.shutdown/2`
    - `Spear.start_scavenge/2`
    - `Spear.stop_scavenge/3`
    - and associated wrappers in `Spear.Client`

## 0.3.0 - 2021-04-18

### Added

- Added record interface modules for all remaining APIs
- Added functions for interacting with the Users API
    - `Spear.change_user_password/5`
    - `Spear.create_user/6`
    - `Spear.delete_user/3`
    - `Spear.disable_user/3`
    - `Spear.enable_user/3`
    - `Spear.reset_user_password/4`
    - `Spear.update_user/6`
    - `Spear.user_details/3`
    - associated functions in `Spear.Client`

## 0.2.1 - 2021-04-17

### Added

- Wrapped new ACL-related functions in `Spear.Client`
    - `c:Spear.Client.get_stream_metadata/2`
    - `c:Spear.Client.set_stream_metadata/2`
    - `c:Spear.Client.set_global_acl/3`

## 0.2.0 - 2021-04-17

### Changed

- Refactored connection configuration to go through validation
    - `:opts` option has been renamed to `:mint_opts`
    - credentials are passed through the `:connection_string` option or
      as `:username` and `:password` options

### Added

- Implemented and documented keep-alive
    - This can be configured through the `keepAliveInterval` and
      `keepAliveTimeout` query params in `:connection_string` or by the
      new `:keep_alive_interval` and `:keep_alive_timeout` configuration
      options

## 0.1.4 - 2021-04-16

### Added

- `{:eos, :closed}` is now emitted when a subscription is broken due to the
  connection between closed between `Spear.Connection` and EventStoreDB
- `Spear.Connection` now monitors subscription processes and cancels
  EventStoreDB subscriptions upon subscriber process exit

## 0.1.3 - 2021-04-15

### Added

- Added documentation and functionality for using TLS certificates
    - see `Spear.Connection` and the [security guide](guides/security.md)
- Added documentation and functionality for setting the global stream ACL
    - see `Spear.set_global_acl/4` and the `Spear.Acl` module
- Added functionality for getting and setting stream-level metadata.
    - `Spear.meta_stream/1`
    - `Spear.get_stream_metadata/3`
    - `Spear.set_stream_metadata/3`
    - `Spear.StreamMetadata`

## 0.1.2 - 2021-04-14

### Added

- Added dependency on [`connection`](https://hex.pm/packages/connection)
- Added ping functionality for `Spear.Connection`s
    - `Spear.ping/1` and `Spear.ping/2`
    - `c:Spear.Client.ping/0` and `c:Spear.Client.ping/1`
- Added the ability to disconnect a connection by `GenServer.call/3`ing it
  with `:close` as the message
- Added the ability to explicitly reconnect a connection by `GenServer.cast/2`ing
  it a message of `:connect`

### Changed

- Changed the internals of `Spear.Connection` to take advantage of the new
  `Connection` dependency
    - A failure to connect on GenServer init for a connection will no longer
      take down the supervision tree
    - Failures to connect will result in back-off retries in 500ms segments
    - The life-cycle of the HTTP2 connection spawned by a `Spear.Connection`
      is now divorced from the life-cycle of the `Spear.Connection` process

## 0.1.1 - 2021-04-14

### Removed

- Removed dependency on `elixir-protobuf/protobuf`
    - see #4
    - also removed all generated files from protobuf

### Added

- Added dependency on `:gpb`
    - and associated generated erlang files
- Added `Spear.Records.*` interface for interacting with gpb-generated records

## 0.1.0 - 2021-04-12

### Added

- Initial implementation of a client for the streams API
    - all notable functions are labeled with the `since: "0.1.0"` doc
      attribute
