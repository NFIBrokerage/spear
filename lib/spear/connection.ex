defmodule Spear.Connection do
  @moduledoc """
  A GenServer which brokers a connection to an EventStore
  """

  # see the very similar original implementation of this from the Mint
  # documentation:
  # https://github.com/elixir-mint/mint/blob/796b8db097d69ede7163acba223ab2045c2773a4/pages/Architecture.md

  use GenServer
  alias Spear.Request

  defstruct [:conn, requests: %{}]

  @post "POST"

  def start_link(opts) do
    name = Keyword.take(opts, [:name])
    rest = Keyword.delete(opts, :name)

    GenServer.start_link(__MODULE__, rest, name)
  end

  @impl GenServer
  def init(config) do
    uri =
      config
      |> Keyword.fetch!(:connection_string)
      |> URI.parse()

    # YARD determine scheme from query params
    # YARD boot this to a handle_continue/2 or handle_cast/2?
    case Mint.HTTP.connect(String.to_atom(uri.scheme), uri.host, uri.port,
           protocols: [:http2],
           mode: :active
         ) do
      {:ok, conn} ->
        {:ok, %__MODULE__{conn: conn}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl GenServer
  def handle_call({:request, request}, from, state) do
    case request_and_stream_body(state, request) do
      {:ok, state, request_ref} ->
        state = put_in(state.requests[request_ref], %{from: from, response: %{}})

        {:noreply, state}

      {:error, state, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp request_and_stream_body(state, request) do
    with {:ok, conn, request_ref} <-
           Mint.HTTP.request(state.conn, @post, request.path, request.headers, :stream),
         state = put_in(state.conn, conn),
         {:ok, state} <- stream_body(state, request_ref, request.messages),
         {:ok, conn} <- Mint.HTTP.stream_request_body(state.conn, request_ref, :eof) do
      {:ok, put_in(state.conn, conn), request_ref}
    else
      {:error, conn, reason} -> {:error, put_in(state.conn, conn), reason}
    end
  end

  @impl GenServer
  def handle_info(message, %{conn: conn} = state) do
    case Mint.HTTP.stream(conn, message) do
      :unknown ->
        # YARD error handling
        {:noreply, state}

      {:ok, conn, responses} ->
        state = put_in(state.conn, conn)

        {:noreply, handle_responses(state, responses)}
    end
  end

  @spec handle_responses(%__MODULE__{}, list()) :: %__MODULE__{}
  defp handle_responses(state, responses) do
    Enum.reduce(responses, state, &process_response/2)
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response[:status], status)
  end

  defp process_response({:headers, request_ref, new_headers}, state) do
    update_in(
      state.requests[request_ref].response[:headers],
      fn headers -> (headers || []) ++ new_headers end
    )
  end

  defp process_response({:data, request_ref, new_data}, state) do
    update_in(
      state.requests[request_ref].response[:data],
      fn data -> (data || <<>>) <> new_data end
    )
  end

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])

    GenServer.reply(from, {:ok, response})

    state
  end

  defp process_response(_unknown, state), do: state

  defp stream_body(state, request_ref, messages) do
    Enum.reduce_while(messages, {:ok, state}, &stream_body_message(&1, &2, request_ref))
  end

  defp stream_body_message(message, {:ok, state}, request_ref) do
    {wire_data, _byte_size} = Request.to_wire_data(message)

    stream_result =
      Mint.HTTP.stream_request_body(
        state.conn,
        request_ref,
        wire_data
      )

    case stream_result do
      {:ok, conn} -> {:cont, {:ok, put_in(state.conn, conn)}}
      {:error, conn, reason} -> {:halt, {:error, put_in(state.conn, conn), reason}}
    end
  end
end
