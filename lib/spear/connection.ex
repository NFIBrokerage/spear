defmodule Spear.Connection do
  @moduledoc """
  A GenServer which brokers a connection to an EventStore
  """

  # see the very similar original implementation of this from the Mint
  # documentation:
  # https://github.com/elixir-mint/mint/blob/796b8db097d69ede7163acba223ab2045c2773a4/pages/Architecture.md

  use GenServer
  alias Spear.Connection.Request

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
    # TODO make request streams and store them in state
    with {:ok, conn, request_ref} <-
           Mint.HTTP.request(state.conn, @post, request.path, request.headers, :stream),
         request = Request.new(request.messages, request_ref, from),
         state = put_in(state.conn, conn),
         state = put_in(state.requests[request_ref], request),
         {:ok, state} <- Request.emit_messages(state, request) do
      {:ok, state}
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
    responses
    |> Enum.reduce(state, &process_response/2)
    |> Request.continue_requests()
  end

  defp process_response({:status, request_ref, status}, state) do
    put_in(state.requests[request_ref].response.status, status)
  end

  defp process_response({:headers, request_ref, new_headers}, state) do
    update_in(
      state.requests[request_ref].response.headers,
      fn headers -> headers ++ new_headers end
    )
  end

  defp process_response({:data, request_ref, new_data}, state) do
    update_in(
      state.requests[request_ref].response.data,
      fn data -> data <> new_data end
    )
  end

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])

    GenServer.reply(from, {:ok, response})

    state
  end

  defp process_response(_unknown, state), do: state
end
