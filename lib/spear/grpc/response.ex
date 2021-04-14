alias Spear.{Connection.Response, Grpc}

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

  def from_connection_response(%Response{status: status}) when status != 200 do
    %__MODULE__{
      status_code: 2,
      status: :unknown,
      message: "Bad HTTP status code: #{inspect(status)}, should be 200"
    }
  end

  def from_connection_response(%Response{type: type, headers: headers, data: data, status: 200}) do
    with {"grpc-status", "0"} <- List.keyfind(headers, "grpc-status", 0),
         {parsed_data, <<>>} <- Grpc.decode_next_message(data, type) do
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

      nil ->
        %__MODULE__{
          status_code: 13,
          status: :internal,
          message: "Error parsing response proto"
        }
    end
  end

  for {code, status} <- @status_code_mapping do
    def map_status(unquote(code)), do: unquote(status)
  end

  def map_status(_), do: :unknown
end
