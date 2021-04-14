# Spear

![CI](https://github.com/NFIBrokerage/spear/workflows/CI/badge.svg)
[![Coverage Status](https://coveralls.io/repos/github/NFIBrokerage/spear/badge.svg)](https://coveralls.io/github/NFIBrokerage/spear)
[![hex.pm version](https://img.shields.io/hexpm/v/spear.svg)](https://hex.pm/packages/spear)
[![hex.pm license](https://img.shields.io/hexpm/l/spear.svg)](https://github.com/NFIBrokerage/spear/blob/master/LICENSE)
[![Last Updated](https://img.shields.io/github/last-commit/NFIBrokerage/spear.svg)](https://github.com/NFIBrokerage/spear/commits/main)

A sharp EventStoreDB 20+ client backed by mint :yum:

## FAQ

**Why the name "spear"?**

1. best gum flavor
1. obligatory programmer reference to ancient greek, roman, or egyptian history
1. sounds cool :sunglasses:

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

**How close is this to being able to be used?**

Check out the roadmap in [#7](https://github.com/NFIBrokerage/spear/issues/7)

## Installation

Add `:spear` to your mix dependencies in `mix.exs`

```elixir
def deps do
  [
    {:spear, "~> 0.1"},
    # If you want to encode events as JSON, :jason is a great library for
    # encoding and decoding and works out-of-the-box with spear.
    # Any JSON (de)serializer should work though, so you don't *need* to add
    # :jason to your dependencies.
    {:jason, "~> 1.0"}
  ]
end
```

## Usage

Familiar with [`Ecto.Repo`](https://hexdocs.pm/ecto/Ecto.Repo.html)? It lets
you write a database connection like a module

```elixir
# note this is for illustration purposes and NOT directly related to Spear
# lib/my_app/repo.ex
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: Ecto.Adapters.Postgres
end
```

and then configure it with application-config (`config/*.exs`)

```elixir
# note this is for illustration purposes and NOT directly related to Spear
# config/config.exs
config :my_app, MyApp.Repo,
  url: "ecto://postgres:postgres@localhost/my_database"
```

Spear lets you do the same with a connection to the EventStoreDB:

```elixir
# lib/my_app/event_store_db_client.ex
defmodule MyApp.EventStoreDbClient do
  use Spear.Client,
    otp_app: :my_app
end
```

and configure it,

```elixir
# config/config.exs
config :my_app, MyApp.EventStoreDbClient,
  connection_string: "esdb://localhost:2113"
```

add it to your application's supervision tree in `lib/my_app/application.ex`

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  use Application

  def start(_type, _args) do
    children = [
      MyApp.EventStoreDbClient
    ]
    
    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

And now you're ready to use spear! Check out the [Spear
documentation](https://hexdocs.pm/spear/Spear.html).

<details><summary>Alternate usages...</summary>
<br>

A `Spear.Connection` is just a regular ole' GenServer with a default of pulling
configuration from application-config. You can start a `Spear.Connection`
like any other process, even in IEx! Plus you can provide the configuration
straight to the `Spear.Connection.start_link/1` function.

Let's use the new `Mix.install/1` function from Elixir 1.12 to try out
Spear. Say that you have an EventStoreDB instance running locally with the
`--insecure option`.

```elixir
iex> Mix.install([:spear, :jason])
# a bunch of installation text here
:ok
iex> {:ok, conn} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")
{:ok, #PID<0.1518.0>}
iex> event = Spear.Event.new("IExAndSpear", %{"hello" => "world"})      
%Spear.Event{
  body: %{"hello" => "world"},
  id: "9e3a8bcf-0c22-4a38-85c6-2054a0342ec8",
  metadata: %{content_type: "application/json", custom_metadata: ""},
  type: "IExAndSpear"
}
iex> [event] |> Spear.append(conn, "MySpearDemo")
:ok
iex> Spear.stream!(conn, "MySpearDemo")
#Stream<[
  enum: #Function<62.80860365/2 in Stream.unfold/2>,
  funs: [#Function<48.80860365/1 in Stream.map/2>]
]>
iex> Spear.stream!(conn, "MySpearDemo") |> Enum.to_list()
[
  %Spear.Event{
    body: %{"hello" => "world"},
    id: "9e3a8bcf-0c22-4a38-85c6-2054a0342ec8",
    metadata: %{
      commit_position: 18446744073709551615,
      content_type: "application/json",
      created: ~U[2021-04-12 20:05:17.757215Z],
      custom_metadata: "",
      prepare_position: 18446744073709551615,
      stream_name: "MySpearDemo",
      stream_revision: 0
    },
    type: "IExAndSpear"
  }
]
```

And we're up and running reading and writing events!

</details>
