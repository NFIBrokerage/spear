defmodule Spear.Request do
  @moduledoc false

  alias Spear.Grpc

  defstruct [
    :service,
    :service_module,
    :rpc,
    :path,
    :headers,
    :messages,
    :credentials
  ]

  def expand(%__MODULE__{service: service, service_module: service_module, rpc: rpc} = request) do
    rpc = Spear.Rpc.expand(service_module, service, rpc)

    %__MODULE__{request | path: rpc.path, headers: headers(), rpc: rpc}
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
  @spec headers({String.t(), String.t()} | any()) :: [{String.t(), String.t()}]
  defp headers(credentials \\ nil) do
    maybe_auth_header =
      case credentials do
        {username, password} ->
          [{"authorization", "Basic " <> Base.encode64("#{username}:#{password}")}]

        _ ->
          []
      end

    [
      {"te", "trailers"},
      # {"grpc-timeout", "10S"},
      {"content-type", "application/grpc+proto"},
      {"grpc-endcoding", "identity"},
      {"grpc-accept-encoding", "identity,deflate,gzip"},
      {"accept-encoding", "identity"},
      {"user-agent", Grpc.user_agent()}
    ] ++ maybe_auth_header
  end

  def merge_credentials(request, connection_credentials) do
    credentials =
      case request.credentials do
        {_username, _password} -> request.credentials
        _ -> connection_credentials
      end

    %__MODULE__{request | credentials: credentials, headers: headers(credentials)}
  end

  @spec to_wire_data(tuple(), module(), atom()) :: {iodata(), pos_integer()}
  def to_wire_data(message, service_module, type) do
    encoded_message = service_module.encode_msg(message, type)
    message_length = byte_size(encoded_message)

    {[<<0::unsigned-integer-8, message_length::unsigned-big-integer-8-unit(4)>>, encoded_message],
     1 + 4 + message_length}
  end
end
