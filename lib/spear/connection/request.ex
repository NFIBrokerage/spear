defmodule Spear.Connection.Request do
  @moduledoc false

  # a struct representing a stream-able request

  @type t :: %{
          continuation: Enumerable.continuation(),
          request_ref: Mint.Types.request_ref(),
          buffer: binary(),
          from: GenServer.from(),
          response: Spear.Connection.Response.t(),
          status: :streaming | :done,
          type: :request | {:subscription, pid(), (binary -> any())}
        }

  import Spear.Records.Streams, only: [read_resp: 1]

  defstruct [:continuation, :buffer, :request_ref, :from, :response, :status, :type]

  def new(
        %Spear.Request{messages: event_stream, rpc: %Spear.Rpc{} = rpc},
        request_ref,
        from,
        type
      ) do
    reducer = &reduce_with_suspend/2

    stream =
      Stream.map(
        event_stream,
        &Spear.Request.to_wire_data(&1, rpc.service_module, rpc.request_type)
      )

    continuation = &Enumerable.reduce(stream, &1, reducer)

    %__MODULE__{
      continuation: continuation,
      buffer: <<>>,
      request_ref: request_ref,
      from: from,
      response: %Spear.Connection.Response{type: {rpc.service_module, rpc.response_type}},
      status: :streaming,
      type: type
    }
  end

  defp reduce_with_suspend(
         {message, message_size},
         {message_buffer, message_buffer_size, max_size}
       )
       when message_size + message_buffer_size > max_size do
    {:suspend,
     {[{message, message_size} | message_buffer], message_size + message_buffer_size, max_size}}
  end

  defp reduce_with_suspend(
         {message, message_size},
         {message_buffer, message_buffer_size, max_size}
       ) do
    {:cont,
     {[{message, message_size} | message_buffer], message_size + message_buffer_size, max_size}}
  end

  @spec emit_messages(%Spear.Connection{}, %__MODULE__{}) ::
          {:ok, %Spear.Connection{}} | {:error, %Spear.Connection{}, reason :: any()}
  def emit_messages(state, %__MODULE__{buffer: <<>>, continuation: continuation} = request) do
    smallest_window = get_smallest_window(state.conn, request.request_ref)

    {:cont, {[], 0, smallest_window}}
    |> continuation.()
    |> handle_contination(state, request)
  end

  def emit_messages(
        state,
        %__MODULE__{buffer: buffer, continuation: continuation} = request
      ) do
    smallest_window = get_smallest_window(state.conn, request.request_ref)

    case buffer do
      <<bytes_to_send::binary-size(smallest_window), rest::binary>> ->
        state
        |> put_request(%__MODULE__{request | buffer: rest})
        |> stream_messages(
          request.request_ref,
          [{bytes_to_send, smallest_window}]
        )

      ^buffer ->
        # buffer is small enough to be sent in one go
        # so we resume the happy path of cramming as many messages as possible
        # into frames
        buffer_size = byte_size(buffer)

        {:cont, {[{buffer, buffer_size}], buffer_size, smallest_window}}
        |> continuation.()
        |> handle_contination(state, request)
    end
  end

  defp handle_contination(
         {finished, {message_buffer, _buffer_size, _max_size}},
         state,
         request
       )
       when finished in [:done, :halted] do
    request = put_in(request.status, :done)

    stream_messages(
      put_request(state, request),
      request.request_ref,
      [:eof | message_buffer]
    )
  end

  defp handle_contination(
         {:suspended,
          {[{overload_message, overload_message_size} | messages_that_fit], buffer_size,
           max_size}, next_continuation},
         state,
         request
       ) do
    # stream messages    :list.reverse(messages_that_fit)
    # turn overload_message into a binary, break it down to allowed size
    # send what any of what the overload_message binary can be sent,
    # add the rest of overload_message binary to the buffer
    fittable_size = max_size - (buffer_size - overload_message_size) - 1

    <<fittable_binary::binary-size(fittable_size), overload_binary::binary>> =
      IO.iodata_to_binary(overload_message)

    request = %__MODULE__{
      request
      | buffer: overload_binary,
        continuation: next_continuation
    }

    state
    |> put_request(request)
    |> stream_messages(
      request.request_ref,
      [{fittable_binary, fittable_size} | messages_that_fit]
    )
  end

  defp stream_messages(state, request_ref, [:eof | others]) do
    case stream_messages(state, request_ref, others) do
      {:ok, state} ->
        stream_single(state, request_ref, :eof)

      # coveralls-ignore-start
      error ->
        error
        # coveralls-ignore-stop
    end
  end

  defp stream_messages(state, request_ref, reversed_messages) when is_list(reversed_messages) do
    body =
      reversed_messages
      |> :lists.reverse()
      |> Enum.map(fn {message, _size} -> message end)

    # write all messages in one shot as iodata
    stream_single(state, request_ref, body)
  end

  defp stream_single(state, request_ref, body) do
    case Mint.HTTP2.stream_request_body(state.conn, request_ref, body) do
      {:ok, conn} ->
        {:ok, put_in(state.conn, conn)}

      {:error, conn, reason} ->
        # coveralls-ignore-start
        {:error, put_in(state.conn, conn), reason}
        # coveralls-ignore-stop
    end
  end

  defp put_request(state, %{request_ref: request_ref} = request) do
    put_in(state.requests[request_ref], request)
  end

  defp get_smallest_window(conn, request_ref) do
    min(
      Mint.HTTP2.get_window_size(conn, :connection),
      safe_get_request_window_size(conn, request_ref)
    )
  end

  defp safe_get_request_window_size(conn, request_ref) do
    if Map.has_key?(conn.ref_to_stream_id, request_ref) do
      Mint.HTTP2.get_window_size(conn, {:request, request_ref})
    else
      :infinity
    end
  end

  def continue_requests(state) do
    state.requests
    |> Enum.filter(fn {_request_ref, request} -> request.status == :streaming end)
    |> Enum.reduce(state, fn {request_ref, request}, state ->
      case emit_messages(state, request) do
        {:ok, state} ->
          state

        {:error, state, reason} ->
          # coveralls-ignore-start
          {%{from: from}, state} = pop_in(state.requests[request_ref])

          GenServer.reply(from, {:error, reason})

          state
          # coveralls-ignore-stop
      end
    end)
  end

  def handle_data(%__MODULE__{type: :request} = request, new_data) do
    update_in(request.response.data, fn data -> data <> new_data end)
  end

  def handle_data(%__MODULE__{type: {:subscription, subscriber, through}} = request, new_data) do
    case Spear.Grpc.decode_next_message(request.response.data <> new_data, request.response.type) do
      {read_resp(content: {:confirmation, _confirmation}), rest} ->
        GenServer.reply(request.from, {:ok, request.request_ref})

        request = put_in(request.from, nil)
        put_in(request.response.data, rest)

      {message, rest} ->
        send(subscriber, through.(message))

        put_in(request.response.data, rest)

      nil ->
        # coveralls-ignore-start
        update_in(request.response.data, fn data -> data <> new_data end)
        # coveralls-ignore-stop
    end
  end
end
