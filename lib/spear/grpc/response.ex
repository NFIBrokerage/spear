alias Spear.{Connection.Response, Grpc, Rpc}

defmodule Grpc.Response do
  @moduledoc false

  # a structure and functions for turning a `Spear.Connection.Response` into
  # a more friendly and usable data structure

  defstruct [:status, :status_code, :message, :data]

  # status code information and usages from
  # https://grpc.github.io/grpc/core/md_doc_statuscodes.html

  @status_code_mapping %{
    0 => :ok,
    1 => :cancelled,
    2 => :unknown,
    3 => :invalid_argument,
    4 => :deadline_exceeded,
    5 => :not_found,
    6 => :already_exists,
    7 => :permission_denied,
    8 => :resource_exhausted,
    9 => :failed_precondition,
    10 => :aborted,
    11 => :out_of_range,
    12 => :unimplemented,
    13 => :internal,
    14 => :unavailable,
    15 => :data_loss,
    16 => :unauthenticated
  }

  def from_connection_response(%Response{status: status}, _request, _raw?) when status != 200 do
    %__MODULE__{
      status_code: 2,
      status: :unknown,
      message: "Bad HTTP status code: #{inspect(status)}, should be 200"
    }
  end

  def from_connection_response(%Response{headers: headers, data: data, status: 200}, rpc, raw?) do
    with {"grpc-status", "0"} <- List.keyfind(headers, "grpc-status", 0),
         {:ok, parsed_data} <- parse_data(data, rpc, raw?) do
      %__MODULE__{
        status_code: 0,
        status: :ok,
        message: "",
        data: parsed_data
      }
    else
      {"grpc-status", other_status} ->
        status_code = String.to_integer(other_status)

        %__MODULE__{
          status_code: status_code,
          status: map_status(status_code),
          message:
            Enum.find_value(headers, fn {k, v} ->
              k == "grpc-message" && v
            end),
          data: data
        }

      _ ->
        %__MODULE__{
          status_code: 13,
          status: :internal,
          message: "Error parsing response proto"
        }
    end
  end

  defp parse_data(data, rpc, raw?)

  defp parse_data(data, _rpc, _raw? = true), do: {:ok, data}

  defp parse_data(data, %Rpc{response_stream?: false} = rpc, _raw?) do
    case Grpc.decode_next_message(data, {rpc.service_module, rpc.response_type}) do
      {parsed, <<>>} -> {:ok, parsed}
      _ -> :error
    end
  end

  defp parse_data(data, %Rpc{response_stream?: true} = rpc, _raw?) do
    import Spear.Records.Streams, only: [read_resp: 1, read_resp_stream_not_found: 0]

    parse_chunk = &Spear.Grpc.decode_next_message(&1, {rpc.service_module, rpc.response_type})

    case parse_chunk.(data) do
      {read_resp(content: {:stream_not_found, read_resp_stream_not_found()}), _rest} ->
        {:ok, []}

      {_message, _rest} ->
        {:ok, Stream.unfold(data, parse_chunk)}

      _ ->
        :error
    end
  end

  for {code, status} <- @status_code_mapping do
    def map_status(unquote(code)), do: unquote(status)
  end

  def map_status(_), do: :unknown
end
