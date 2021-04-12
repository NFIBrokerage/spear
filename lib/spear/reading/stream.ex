defmodule Spear.Reading.Stream do
  @moduledoc false

  defstruct [
    :connection,
    :stream,
    :from,
    :max_count,
    :direction,
    :resolve_links?,
    :timeout,
    :buffer
  ]

  @type t :: %__MODULE__{}

  alias Spear.Reading
  alias Spear.Protos.EventStore.Client.Streams.{ReadReq, ReadResp, Streams.Service}

  def new!(opts) do
    state = struct(__MODULE__, opts)
    response = request!(state)

    wrap_buffer_in_decode_stream(
      state,
      response.data,
      &unfold_continuous/1
    )
  end

  @spec read_chunk(Keyword.t()) :: {:ok, Enumerable.t()} | {:error, any()}
  def read_chunk(opts) do
    state = struct(__MODULE__, opts)

    case request(state) do
      {:ok, response} ->
        stream =
          wrap_buffer_in_decode_stream(
            state,
            response.data,
            &unfold_chunk/1
          )

        {:ok, stream}

      # coveralls-ignore-start
      error ->
        error
        # coveralls-ignore-stop
    end
  end

  def wrap_buffer_in_decode_stream(state, buffer, unfold_fn) do
    case unfold_chunk(buffer) do
      {%ReadResp{content: {:stream_not_found, %ReadResp.StreamNotFound{}}}, _rest} ->
        []

      {message, rest} ->
        buffer = if state.from |> is_atom(), do: buffer, else: rest

        Stream.unfold(
          %__MODULE__{state | buffer: buffer, from: message},
          unfold_fn
        )

      nil ->
        []
    end
  end

  defp request(state) do
    request = Reading.build_read_request(state)

    GenServer.call(state.connection, {:request, build_request(request)}, state.timeout)
  end

  defp request!(state) do
    {:ok, response} = request(state)

    response
  end

  defp build_request(message) do
    %Spear.Request{
      service: Service,
      rpc: :Read,
      messages: [message]
    }
    |> Spear.Request.expand()
  end

  @spec unfold_chunk(binary() | %__MODULE__{}) :: {struct(), binary()} | nil
  def unfold_chunk(%__MODULE__{} = state), do: unfold_chunk(state.buffer)

  def unfold_chunk(buffer) when is_binary(buffer) do
    Spear.Grpc.decode_next_message(buffer, ReadResp)
  end

  # in this case the buffer has run dry and we need to request more events
  # (a new buffer) with a new ReadReq
  @spec unfold_continuous(t()) :: {emitted_element :: ReadReq.t(), t()} | nil
  defp unfold_continuous(%__MODULE__{buffer: <<>>, from: from} = state) do
    response = request!(%__MODULE__{state | max_count: state.max_count + 1})

    case unfold_chunk(response.data) do
      # discard the first message since it is `from`
      {^from, <<_head, _::binary>> = rest} ->
        unfold_continuous(%__MODULE__{state | buffer: rest})

      _ ->
        nil
    end
  end

  defp unfold_continuous(%__MODULE__{buffer: buffer} = state) do
    case unfold_chunk(buffer) do
      {%_{} = message, remaining_buffer} ->
        {message, %__MODULE__{state | buffer: remaining_buffer, from: message}}

      _ ->
        nil
    end
  end
end
