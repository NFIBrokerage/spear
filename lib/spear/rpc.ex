defmodule Spear.Rpc do
  @moduledoc false

  # simple struct for an RPC definiton, used by Spear.Service

  defstruct [
    :request_type,
    :response_type,
    :request_stream?,
    :response_stream?,
    :path,
    :name,
    :service
  ]
end
