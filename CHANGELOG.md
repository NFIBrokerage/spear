# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.2.0 - [Unreleased]

### Changed

- Refactored connection configuration to go through validation
    - `:opts` option has been renamed to `:mint_opts`
    - credentials are passed through the `:connection_string` option or
      as `:username` and `:password` options

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
