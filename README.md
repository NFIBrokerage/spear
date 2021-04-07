# Spear

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

**Why not `elixir-grpc/grpc`?**

That project looks good but it depends on `:gun` which doesn't play nice with
other dependencies. It also provides a server and client implementation in
one library. This library only needs a client.
