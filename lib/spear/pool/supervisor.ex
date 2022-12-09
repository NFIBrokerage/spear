defmodule Spear.Pool.Supervisor do
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
        on_connect: Spear.Pool.PoolUtils.on_connect_fun(SpearPoolRegistry, :connections),
        on_disconnect: Spear.Pool.PoolUtils.on_disconnect_fun(SpearPoolRegistry, :connections)
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

    Spear.Pool.PoolUtils.init()

    children = [
      {Registry, name: SpearPoolRegistry, keys: :duplicate},
      connections_supervisor_spec
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def get_conn() do
    connections = Registry.lookup(SpearPoolRegistry, :connections)
    next_index = Spear.Pool.PoolUtils.read_and_increment()

    # We get the connection in the list at the incremented index, modulo
    # the number of connections in the list (so that we wrap around).
    {pid, _value = nil} = Enum.at(connections, rem(next_index, length(connections)))
    {:ok, pid}
  end
end
