defmodule Spear.Client do
  @moduledoc """
  A macro for defining a module which represents a connection to an EventStore

  Like an `Ecto.Repo` or an `Extreme` client, this macro allows you to call
  functions on the module representing the connection instead of passing
  the connection pid or name as an argument to functions in `Spear`. This
  can be useful for client connections central to a service.

  If a service does not know which connections it may need until runtime, the
  functions in Spear may be used with a connection processes spawned via
  `DynamicSupervisor.start_child/2`.
  """

  defmacro __using__(_opts) do
    quote do
      def read_stream(stream_name, opts \\ []) do
        Spear.read_stream(__MODULE__, stream_name, opts)
      end
    end
  end
end
