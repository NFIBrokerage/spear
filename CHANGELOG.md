# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a
Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--

## [Unreleased]

### Added

- foo
- bar
- baz

-->

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
