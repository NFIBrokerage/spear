# Pooling

While "checkout" or "exclusive" pools are not recommended for HTTP/2
connections, so-called "routing" pools may lead to better performances
by balancing the calls between multiple connections. A more detailed
explanation of routing pools in Elixir can be found in Andrea Leopardi's
blog post [Process pools with Elixir's Registry](https://andrealeopardi.com/posts/process-pools-with-elixirs-registry/).

Since it's difficult to provide a one-size-fits-all routing strategy,
`Spear` doesn't provide such a pooling mechanism out of the box.
However,thanks to the `:on_connect` and `:on_disconnect` configuration 
options passed to `Spear.Connection.start_link`, it's fairly easy to
implement your own routing pool.

This guide provides an example of a simple round-robin routing pool
inspired by the aforementioned blog post.

### Writing the pool

First let's write a few utility functions that will allow us to keep
track of the connections in the pool :

```elixir
defmodule MyApp.Spear.Pool.PoolUtils do

  def init() do
    # Create a `persistent_term` that holds an atomic counter if it
    #  doesn't already exist
    maybe_create_persistent_term()
  end

  # Increment and read our counter
  def read_and_increment() do
    counter_ref = :persistent_term.get(__MODULE__)
    :atomics.add_get(counter_ref, 1, 1)
  end

  # Create a fun that we'll pass to `:on_connect`
  def on_connect_fun(registry_name, key, value \\ nil) do
    # The fun will be called in the context of the connection which is
    # what we want
    fn -> Registry.register(registry_name, key, value) end
  end

  # Create a fun that we'll pass to `:on_disconnect`
  def on_disconnect_fun(registry_name, key) do
    fn -> Registry.unregister(registry_name, key) end
  end

  defp maybe_create_persistent_term() do
    case :persistent_term.get(__MODULE__, nil) do
      counter when is_reference(counter) ->
        # We don't really care if we start at the 2nd connection, since it's simple round robin
        :atomics.put(counter, 1, 0)
        :ok

      _ ->
        counter = :atomics.new(1, signed: false)
        :atomics.put(counter, 1, 0)
        :persistent_term.put(__MODULE__, counter)
    end
  end
end
```

Now, we can add a `Supervisor` that will manage our registry and our
connections pool :

```elixir
defmodule MyApp.Spear.Pool.Supervisor do
  use Supervisor

  def start_link(args) do
    Supervisor.start_link(__MODULE__, args)
  end

  @impl Supervisor
  def init(args) do
    init_args = Keyword.get(args, :connection_args)
    num_members = Keyword.get(args, :num_members, 1)

    connection_args =
      Keyword.merge(init_args,
        on_connect: MyApp.Spear.Pool.PoolUtils.on_connect_fun(MyApp.SpearPoolRegistry, :connections),
        on_disconnect: MyApp.Spear.Pool.PoolUtils.on_disconnect_fun(MyApp.SpearPoolRegistry, :connections)
      )

    connections_specs =
      for index <- 1..num_members do
        Supervisor.child_spec({Spear.Connection, connection_args}, id: {Spear.Connection, index})
      end

    connections_supervisor_spec = %{
      id: :connections_supervisor,
      type: :supervisor,
      start: {Supervisor, :start_link, [connections_specs, [strategy: :one_for_one]]}
    }

    MyApp.Spear.Pool.PoolUtils.init()

    children = [
      {Registry, name: MyApp.SpearPoolRegistry, keys: :duplicate},
      connections_supervisor_spec
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def get_conn() do
    connections = Registry.lookup(MyApp.SpearPoolRegistry, :connections)
    next_index = MyApp.Spear.Pool.PoolUtils.read_and_increment()

    # We get the connection in the list at the incremented index, modulo
    # the number of connections in the list (so that we wrap around).
    {pid, _value = nil} = Enum.at(connections, rem(next_index, length(connections)))
    {:ok, pid}
  end
end
```

### Using the pool

After starting the pool (usually through your app's supervision tree) :

```elixir
{:ok, pool} =
  MyApp.Spear.Pool.Supervisor.start_link(
    num_members: 10,
    connection_args: [connection_string: "esdb://admin:changeit@127.0.0.1:2113"]
  )
```

You can obtain a `Spear.Connection` from the pool :

```elixir
{:ok, conn} = MyApp.Spear.Pool.Supervisor.get_conn()
```

And use it with the `Spear` module :

```elixir
e = Spear.Event.new("test-event", %{title: "some title"})
Spear.append([e], conn, "stream1")
```

### Caveats

HTTP/2 and Mint, thus Spear, allow to process efficiently multiple requests
on a single connection. A routing pool could actually degrade your app's
performances. Therefore, when using such a pool, it is important to
carefully benchmark the results for your use-case, maybe with different
routing strategies.

As a rule of thumb, a routing pool might be beneficial when you perform
many concurrent reads (eg through `Spear.stream!/3`) or many concurrent
writes of large events/list of events. In any case, benchmarking is
always recommended.






