defmodule Spear.Request do
  @moduledoc false

  alias Spear.Grpc

  defstruct [
    :service,
    :rpc,
    :path,
    :headers,
    :messages,
    :batch_size,
    :request_module,
    :response_module,
    :request_is_stream?,
    :response_is_stream?
  ]

  def expand(%__MODULE__{service: service, rpc: rpc} = request) do
    rpc = service.rpc(rpc)

    %__MODULE__{
      request
      | path: rpc.path,
        headers: headers(rpc.request_type),
        rpc: rpc
    }
  end

  # N.B. these headers are in a particular order according to the gRPC
  # HTTP2 spec, which I will quote as follows (ABNF syntax)
  #
  # Request-Headers → Call-Definition *Custom-Metadata
  # Call-Definition → Method Scheme Path TE [Authority] [Timeout] Content-Type [Message-Type] [Message-Encoding] [Message-Accept-Encoding] [User-Agent]
  #
  # notes:
  # - the method, scheme, and path headers are set as pseudoheaders
  #   by Mint
  #     - DO NOT specify them here as this will duplicate the pseudoheaders
  # - custom_metadata may come after the headers returned by this function
  #     - this makes `++/2` a good choice for appending custom metadata
  #     - note that custom headers may not begin with "grpc-"
  @spec headers(module()) :: [{String.t(), String.t()}]
  defp headers(request_module) do
    [
      {"te", "trailers"},
      # {"grpc-timeout", "10S"},
      {"content-type", "application/grpc+proto"},
      {"grpc-message-type", request_module.message_type()},
      {"grpc-endcoding", "identity"},
      {"grpc-accept-encoding", "identity,deflate,gzip"},
      {"accept-encoding", "identity"},
      {"user-agent", Grpc.user_agent()}
    ]
  end

  @spec to_wire_data(struct()) :: {iodata(), pos_integer()}
  def to_wire_data(%_{} = message) do
    encoded_message = encode(message)
    message_length = IO.iodata_length(encoded_message)

    {[<<0::unsigned-integer-8, message_length::unsigned-big-integer-8-unit(4)>>, encoded_message],
     1 + 4 + message_length}
  end

  @spec encode(struct()) :: iodata()
  defp encode(%_{} = message), do: Protobuf.Encoder.encode(message, iolist: true)
end
