defmodule Spear do
  @moduledoc """
  Documentation for `Spear`.
  """

  require Mint.HTTP

  @rpc "BidiHello"
  @service "/#{Hello.HelloService.Service.__meta__(:name)}/#{@rpc}"
  @headers [
    {"grpc-timeout", "10S"},
    {"content-type", "application/grpc+proto"},
    {"user-agent", "grpc-elixir-spear/0.0.1 (spear 0.0.1; mint 1.2.1)"},
    {"te", "trailers"}
  ]
  @compressed_flag <<0x00>>
  @message_data Hello.HelloRequest.new(greeting: "ohai") |> Protobuf.Encoder.encode(iolist: true)
  @message_length <<IO.iodata_length(@message_data)::unsigned-big-integer-8-unit(4)>>
  @data [@compressed_flag | [@message_length | @message_data]]

  def do_grpc do
    {:ok, conn} = Mint.HTTP2.connect(:http, "grpcb.in", 9000)

    {:ok, conn, request_ref} = Mint.HTTP.request(conn, "POST", @service, @headers, :stream)
    {:ok, conn} = Mint.HTTP.stream_request_body(conn, request_ref, @data)
    {:ok, conn} = Mint.HTTP.stream_request_body(conn, request_ref, @data)
    {:ok, conn} = Mint.HTTP.stream_request_body(conn, request_ref, @data)
    {:ok, conn} = Mint.HTTP.stream_request_body(conn, request_ref, :eof)

    {:ok, conn, responses} = get_until_done(conn)

    Mint.HTTP.close(conn)

    responses
    |> into_map()
    |> parse_data(Hello.HelloResponse)
  end

  def get_until_done(conn, acc \\ []) do
    receive do
      message when Mint.HTTP.is_connection_message(conn, message) ->
        {:ok, conn, responses} = Mint.HTTP.stream(conn, message)
        acc = responses ++ acc

        if Enum.any?(responses, &match?({:done, _reference}, &1)) do
          {:ok, conn, acc}
        else
          get_until_done(conn, acc)
        end
    after
      10_000 -> {:error, :timeout}
    end
  end

  def into_map(responses) do
    Enum.reduce(responses, %{}, fn
      {:status, _ref, status}, acc -> Map.put(acc, :http_status, status)
      {:headers, _ref, headers}, acc -> Map.update(acc, :headers, headers, &(&1 ++ headers))
      {:data, _ref, data}, acc -> Map.update(acc, :data, data, &(&1 <> data))
      {key, _ref, value}, acc -> Map.put(acc, key, value)
      {:done, _ref}, acc -> acc
    end)
  end

  def parse_data(response, response_module) when is_map(response) do
    Map.put(
      response,
      :parsed_data,
      parse_data(response.data, &response_module.decode/1, [])
    )
  end

  # base case: no more DATA frame to parse
  def parse_data(<<>>, _response_module, acc), do: Enum.reverse(acc)

  # happy path of parsing DATA frame(s)
  #
  # from the specification (https://github.com/grpc/grpc/blob/fd27fb09b028e5823f3f246e90bad2d02dfd90d3/doc/PROTOCOL-HTTP2.md)
  # format: ABNF
  #
  # begin quote
  #
  # The repeated sequence of Length-Prefixed-Message items is delivered in DATA frames
  #
  # * Length-Prefixed-Message → Compressed-Flag Message-Length Message
  # * Compressed-Flag → 0 / 1 # encoded as 1 byte unsigned integer
  # * Message-Length → {length of Message} # encoded as 4 byte unsigned integer (big endian)
  # * Message → *{binary octet}
  #
  # end quote
  #
  # notes:
  # - "1 byte unsigned integer" is 8 bits, hence `unsigned-integer-8`
  # - `unit(4)` captures 4 bytes for the message_length
  # - endianness does not matter when the binary in question is 1 byte
  #   hence big/little is not specified for `compressed_flag` (however the
  #   default according to the Elixir documentation is big endian).
  #     - it _does_ matter for message_length however which is 4 bytes
  #     - this is why the specification says "big endian" for the message_length
  def parse_data(
        <<compressed_flag::unsigned-integer-8, message_length::unsigned-big-integer-8-unit(4),
          message::binary-size(message_length), rest::binary>>,
        decode_fn,
        acc
      )
      when compressed_flag in [0, 1] do
    parse_data(rest, decode_fn, [decode_fn.(message) | acc])
  end

  # sad path: a malformed frame, either which does not have a compression flag
  # or has a `message` binary smaller than the `message_byte_size` declares it
  # should
  def parse_data(<<_malformed::binary>>, decode_fn, acc) do
    parse_data(<<>>, decode_fn, acc)
  end
end
