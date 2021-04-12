# coveralls-ignore-start
defmodule Spear.Service do
  @moduledoc false

  # N.B. this was originally copied whole-sale from
  #
  # https://github.com/elixir-grpc/grpc/blob/eff8a8828d27ddd7f63a3c1dd5aae86246df215e/lib/grpc/service.ex
  #
  # because the protobuf generator for `protoc` generates this service
  # definition
  #
  # and frankly I kinda like the syntax
  #
  # nevertheless I think it's a bit of a hostile practice to have a canonical
  # generator tool force library choice
  # and I think this macro _should_ belong to the Protobuf library
  #
  # the original implementation has been modified to have a friendlier
  # API

  defmacro __using__(opts) do
    quote do
      import Spear.Service, only: [rpc: 3, stream: 1]

      Module.register_attribute(__MODULE__, :rpc_calls, accumulate: true)
      @before_compile Spear.Service

      def name, do: unquote(opts[:name])
    end
  end

  defmacro __before_compile__(env) do
    rpc_calls = Module.get_attribute(env.module, :rpc_calls)
    all_rpcs = Enum.map(rpc_calls, fn {name, _req, _res} -> name end)

    rpc_details =
      for {name, {request_type, request_stream?}, {response_type, response_stream?}} <- rpc_calls do
        quote do
          def rpc(unquote(name)) do
            %Spear.Rpc{
              service: __MODULE__,
              name: unquote(name),
              path: "/#{name()}/#{unquote(name)}",
              request_type: unquote(request_type),
              request_stream?: unquote(request_stream?),
              response_type: unquote(response_type),
              response_stream?: unquote(response_stream?)
            }
          end
        end
      end

    quote do
      def rpcs, do: unquote(all_rpcs)

      unquote(rpc_details)
    end
  end

  defmacro rpc(name, request, reply) do
    quote do
      @rpc_calls {unquote(name), unquote(wrap_stream(request)), unquote(wrap_stream(reply))}
    end
  end

  def stream(param) do
    quote do: {unquote(param), true}
  end

  def wrap_stream({:stream, _, _} = param) do
    quote do: unquote(param)
  end

  def wrap_stream(param) do
    quote do: {unquote(param), false}
  end
end

# coveralls-ignore-stop
