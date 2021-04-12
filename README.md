# Spear

![CI](https://github.com/NFIBrokerage/spear/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/NFIBrokerage/spear/badge.svg)](https://coveralls.io/github/NFIBrokerage/spear)
[![Last Updated](https://img.shields.io/github/last-commit/NFIBrokerage/spear.svg)](https://github.com/NFIBrokerage/spear/commits/main)

A sharp EventStore 20+ client backed by mint :yum:

## FAQ

**Why the name "spear"?**

1. best gum flavor
1. obligatory reference to ancient greek, roman, or egyptian history
1. sounds cool :sunglasses:

<!--

haven't added any formatter exports yet, but reserve the right

**Why is the formatter doing weird stuff to my definitions?**

No. It's just trying to do its job you leave it alone.

Every once in a while it needs a hint. After adding `:spear` to the
`deps/0` in your `mix.exs`, add this to the keyword list in
the `.formatter.exs` (creating if not already there):

```elixir
# formatter.exs
[
  import_deps: [:spear]
]
```

-->

**Backed by... Mint?**

[`elixir-mint/mint`](https://github.com/elixir-mint/mint) is a functional
HTTP client which supports HTTP2.

As the kids say these days, gRPC is spicy HTTP2. Practically speaking,
gRPC just adds some well-known headers and a message format that allows
messages to not be aligned with HTTP2 DATA frames.  It's relatively trivial
to implement gRPC with a nice HTTP2 library like mint :slightly_smiling_face:.

**Why not [`elixir-grpc/grpc`](https://github.com/elixir-grpc/grpc)?**

That project looks good but it depends on
[`:gun`](https://github.com/ninenines/gun) which doesn't play nice with
other dependencies. It also provides a server and client implementation in
one library. This library only needs a client.

<!--

Wanted to keep this #shade out of the online+viewable readme:

Also the code hygiene is... questionable 🤔
https://github.com/elixir-grpc/grpc/blob/eff8a8828d27ddd7f63a3c1dd5aae86246df215e/lib/grpc/adapter/gun.ex#L170-L262

-->

**How close is this to being usable?**

Here's the general plan:

- v0.1.0: Streams API (`streams.proto`) [**in progress**]
- v0.1.1: TLS documentation
- v0.2.0: Operations API (`operations.proto`)
- v0.3.0: Users API (`users.proto`)
- v0.4.0: Projections API (`projections.proto`)
- v0.5.0: Persistent Subscriptions API (`persistent.proto`)
- Broadway integration for persistent subscriptions API
    - see [`NFIBrokerage/radical`](https://github.com/NFIBrokerage/radical) for the TCP-client driven version of this
    - tentative name: `volley`

And the docket for getting v0.1.0 up into Hex:

- [x] basic streams API
- [x] reasonable first-draft of documentation
- [x] server-side filtering implementation
- [x] server-side filtering documentation
- [x] testing
- [x] library QoL improvements
    - CI
    - auto-publish on tag push
- [x] replace/upgrade Spear.Service implementation
