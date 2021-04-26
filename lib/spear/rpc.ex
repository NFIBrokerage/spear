defmodule Spear.Rpc do
  @moduledoc false
  require Record

  # simple struct for an RPC definiton, used by Spear.Service

  @type t :: %__MODULE__{}

  defstruct [
    :request_type,
    :response_type,
    :request_stream?,
    :response_stream?,
    :path,
    :name,
    :service,
    :service_module
  ]

  Record.defrecordp(:rpc, Record.extract(:rpc, from_lib: "gpb/include/gpb.hrl"))

  def expand(service_module, service, rpc) do
    rpc(name: ^rpc) = this_rpc = service_module.fetch_rpc_def(service, rpc)

    %__MODULE__{
      name: rpc(this_rpc, :name),
      request_type: rpc(this_rpc, :input),
      request_stream?: rpc(this_rpc, :input_stream),
      response_type: rpc(this_rpc, :output),
      response_stream?: rpc(this_rpc, :output_stream),
      service: service,
      service_module: service_module,
      path: "/#{service}/#{rpc}"
    }
  end
end
