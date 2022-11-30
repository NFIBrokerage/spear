defmodule Spear.Pool.PoolTable do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  def init([]) do
    ets = :ets.new(__MODULE__, [:public, :named_table, {:read_concurrency, true}])
    # We don't really care if we start at the 2nd connection, since it's simple round robin
    counter_ref = :atomics.new(1, signed: false)
    :atomics.put(counter_ref, 1, 0)
    :ets.insert(__MODULE__, {:counter_ref, counter_ref})
    {:ok, ets}
  end

  def read_and_increment do
    counter_ref = :ets.lookup_element(__MODULE__, _key = :counter_ref, _pos = 2)
    :atomics.add_get(counter_ref, 1, 1)
  end
end
