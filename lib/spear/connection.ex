defmodule Spear.Connection do
  @moduledoc """
  A GenServer which brokers a connection to an EventStore

  <!--

  ## Configuration

  TODO

  -->

  ## Examples

      iex> {:ok, conn} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")
      iex> Spear.stream!(conn, "es_supported_clients") |> Enum.take(3)
      [%Spear.Event{}, %Spear.Event{}, %Spear.Event{}]
  """

  # see the very similar original implementation of this from the Mint
  # documentation:
  # https://github.com/elixir-mint/mint/blob/796b8db097d69ede7163acba223ab2045c2773a4/pages/Architecture.md

  use GenServer
  alias Spear.Connection.Request

  defstruct [:conn, requests: %{}]

  @post "POST"

  @doc false
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
      |> set_esdb_scheme()

    # YARD determine scheme from query params
    # YARD boot this to a handle_continue/2 or handle_cast/2?
    case Mint.HTTP.connect(uri.scheme, uri.host, uri.port,
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
  def handle_call({:cancel, request_ref}, _from, state) when is_reference(request_ref) do
    with true <- Map.has_key?(state.requests, request_ref),
         {:ok, conn} <- Mint.HTTP2.cancel_request(state.conn, request_ref) do
      {:reply, :ok, put_in(state.conn, conn)}
    else
      false ->
        # idempotent success when the request_ref is not active
        {:reply, :ok, state}

      {:error, conn, reason} ->
        {:reply, {:error, reason}, put_in(state.conn, conn)}
    end
  end

  def handle_call({type, request}, from, state) do
    case request_and_stream_body(state, request, from, type) do
      {:ok, state} ->
        {:noreply, state}

      {:error, state, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp request_and_stream_body(state, request, from, request_type) do
    with {:ok, conn, request_ref} <-
           Mint.HTTP.request(state.conn, @post, request.path, request.headers, :stream),
         request = Request.new(request, request_ref, from, request_type),
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
      state.requests[request_ref],
      &Request.handle_data(&1, new_data)
    )
  end

  defp process_response({:done, request_ref}, state) do
    {%{response: response, from: from}, state} = pop_in(state.requests[request_ref])

    GenServer.reply(from, {:ok, response})

    state
  end

  defp process_response(_unknown, state), do: state

  defp set_esdb_scheme(%URI{scheme: "esdb"} = uri), do: %URI{uri | scheme: :http}
  defp set_esdb_scheme(%URI{scheme: "http"} = uri), do: %URI{uri | scheme: :http}
end
