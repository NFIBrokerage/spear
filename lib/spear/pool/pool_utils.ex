defmodule Spear.Pool.PoolUtils do
  def init() do
    maybe_create_persistent_term()
  end

  def read_and_increment() do
    counter_ref = :persistent_term.get(__MODULE__)
    :atomics.add_get(counter_ref, 1, 1)
  end

  def on_connect_fun(registry_name, key, value \\ nil) do
    fn -> Registry.register(registry_name, key, value) end
  end

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
