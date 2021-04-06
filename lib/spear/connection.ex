defmodule Spear.Connection do
  @moduledoc """
  A GenServer which brokers a connection to an EventStore
  """

  # see the very similar original implementation of this from the Mint
  # documentation:
  # https://github.com/elixir-mint/mint/blob/796b8db097d69ede7163acba223ab2045c2773a4/pages/Architecture.md

  use GenServer
  alias Spear.Request
  require Mint.HTTP

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
    case request_and_stream_body(state, request, from) do
      {:ok, state} ->
        {:noreply, state}

      {:error, state, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp request_and_stream_body(state, request, from) do
    with {:ok, conn, request_ref} <-
           Mint.HTTP.request(state.conn, @post, request.path, request.headers, :stream),
         state = put_in(state.conn, conn),
         state = put_in(state.requests[request_ref], %{from: from, response: %{}}),
         {:ok, state} <- stream_body(state, request_ref, request.messages),
         {:ok, conn} <- Mint.HTTP.stream_request_body(state.conn, request_ref, :eof) do
      {:ok, put_in(state.conn, conn)}
    else
      {:error, %__MODULE__{} = state, reason} -> {:error, state, reason}
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
    Enum.reduce_while(
      messages,
      {:ok, state},
      &stream_body_message(&1, &2, request_ref)
    )
  end

  defp stream_body_message(message, {:ok, state}, request_ref) do
    {wire_data, byte_size} = Request.to_wire_data(message)
    smallest_window = get_smallest_window(state.conn, request_ref)

    with false <- byte_size > smallest_window,
         {:ok, conn} <- Mint.HTTP.stream_request_body(state.conn, request_ref, wire_data) do
      {:cont, {:ok, put_in(state.conn, conn)}}
    else
      _window_too_small? = true ->
        recv_until_window_size_increase(state, smallest_window, request_ref)

      {:error, conn, reason} ->
        {:halt, {:error, put_in(state.conn, conn), reason}}
    end
  end

  defp recv_until_window_size_increase(state, current_window, request_ref) do
    params = {current_window, request_ref}

    {:ok, state}
    # |> do_stage(:set_passive_mode, params)
    |> do_stage(:recv_responses, params)
    |> do_stage(:check_window_size, params)
    # |> do_stage(:set_active_mode, params)
    |> emit_stage_results()
  end

  defp do_stage({:error, state, reason}, _stage, _params), do: {:error, state, reason}

  # defp do_stage({:ok, state}, :set_passive_mode, _params) do
  # case Mint.HTTP.set_mode(state.conn, :passive) do
  # {:ok, conn} -> {:ok, put_in(state.conn, conn)}
  # {:error, reason} -> {:error, state, reason}
  # end
  # end

  defp do_stage({:ok, state}, :recv_responses, {_current_window, _request_ref}) do
    case receive_next_and_stream(state.conn) do
      {:ok, conn, responses} ->
        state =
          put_in(state.conn, conn)
          |> handle_responses(responses)

        {:ok, state}

      {:error, conn, reason} ->
        state = put_in(state.conn, conn)

        {:error, state, reason}
    end
  end

  defp do_stage({:ok, state}, :check_window_size, {current_window, request_ref}) do
    new_window = get_smallest_window(state.conn, request_ref)

    if new_window > current_window do
      {:ok, state}
    else
      # if the window has not gotten bigger, loop back to the prior stage
      # in the pipeline: block and wait for more messages from the server
      do_stage({:ok, state}, :recv_responses, {new_window, request_ref})
    end
  end

  # defp do_stage({:ok, state}, :set_active_mode, _params) do
  # case Mint.HTTP.set_mode(state.conn, :active) do
  # {:ok, conn} -> {:ok, put_in(state.conn, conn)}
  # {:error, reason} -> {:error, state, reason}
  # end
  # end

  defp emit_stage_results({:ok, state}), do: {:cont, {:ok, state}}
  defp emit_stage_results({:error, state, reason}), do: {:halt, {:error, state, reason}}

  defp receive_next_and_stream(conn) do
    # YARD allow customization of timeout?
    receive do
      message when Mint.HTTP.is_connection_message(conn, message) ->
        Mint.HTTP.stream(conn, message)
    after
      1_000 ->
        {:error, conn, :window_update_timeout}
    end
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
end
