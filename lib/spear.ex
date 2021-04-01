defmodule Spear do
  @moduledoc """
  Documentation for `Spear`.
  """

  require Mint.HTTP

  def do_http2 do
    {:ok, conn} = Mint.HTTP2.connect(:http, "nghttp2.org", 80)
    {:ok, conn, _request_ref} = Mint.HTTP.request(conn, "GET", "/robots.txt", [], nil)

    receive do
      message when Mint.HTTP.is_connection_message(conn, message) ->
        {:ok, conn, responses} = Mint.HTTP.stream(conn, message)
        Mint.HTTP.close(conn)
        {:ok, responses}
    after
      5_000 -> {:error, :timeout}
    end
  end

  @service "/#{Hello.HelloService.Service.__meta__(:name)}/SayHello"
  @headers [
    {"grpc-timeout", "10S"},
    {"content-type", "application/grpc+proto"},
    {"user-agent", "grpc-elixir-spear/0.0.1 (spear 0.0.1; mint 1.2.1)"},
    {"te", "trailers"}
  ]
  @compressed_flag <<0x00>>
  @message_data Hello.HelloRequest.new(greeting: "hello from grpc-elixir") |> Hello.HelloRequest.encode()
  @message_length <<byte_size(@message_data)::unsigned-big-integer-8-unit(4)>>
  @data [@compressed_flag | [@message_length | @message_data]]

  def do_grpc do
    {:ok, conn} = Mint.HTTP2.connect(:http, "grpcb.in", 9000)

    {:ok, conn, request_ref} = Mint.HTTP.request(conn, "POST", @service, @headers, @data)
    # {:ok, conn} = Mint.HTTP.stream_request_body(conn, request_ref, @data)
    # {:ok, conn} = Mint.HTTP.stream_request_body(conn, request_ref, :eof)

    IO.inspect(request_ref, label: "request_ref")

    {:ok, conn, responses_two} = get_until_done(conn)

    Mint.HTTP.close(conn)

    responses_two
    |> into_map()
    |> parse_data(Hello.HelloResponse)
  end

  def get_until_done(conn, acc \\ []) do
    receive do
      message ->
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
      {key, _ref, value}, acc -> Map.put(acc, key, value)
      {:done, _ref}, acc -> acc
    end)
  end

  def parse_data(response, response_module) when is_map(response) do
    Map.put(response, :parsed_data, parse_data(response.data, response_module))
  end

  def parse_data(<<_compression, _byte_size::unsigned-big-integer-8-unit(4), message_data::binary>>, response_module) do
    response_module.decode(message_data)
  end
end
