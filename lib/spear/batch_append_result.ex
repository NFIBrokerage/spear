defmodule Spear.BatchAppendResult do
  @moduledoc """
  A data structure representing the response to a batch-append request

  This structure is sent to the `:send_ack_to` option when using
  `Spear.append_batch/5`.
  """
  @moduledoc since: "0.10.0"

  require Spear.Records.Streams, as: Streams
  require Spear.Records.Status, as: Status
  require Spear.Records.Google, as: Google

  @typedoc """
  A response to a batch-append request

  When the batch-append succeeds, EventStoreDB returns the current revision
  and position info in the appended stream. These fields will be `nil` if
  the append does not succeed.
  """
  @typedoc since: "0.10.0"
  @type t :: %__MODULE__{
          request_id: reference(),
          batch_id: String.t(),
          result: :ok | {:error, %Spear.Grpc.Response{}} | tuple(),
          revision: non_neg_integer() | :empty | nil,
          position: Spear.Position.t() | :empty | nil
        }

  defstruct [:request_id, :batch_id, :result, :revision, :position]

  @doc false
  def from_record(
        Streams.batch_append_resp(correlation_id: batch_id, result: result),
        request_id,
        raw?
      ) do
    %__MODULE__{
      result: map_result(result, raw?),
      batch_id: Spear.Uuid.from_proto(batch_id),
      request_id: request_id,
      revision: map_revision(result),
      position: map_position(result)
    }
  end

  # coveralls-ignore-start
  defp map_result(result, true), do: result

  # coveralls-ignore-stop

  defp map_result({:success, Streams.batch_append_resp_success()}, _raw?) do
    :ok
  end

  defp map_result({:error, Status.status(code: code, message: message)}, _raw?) do
    status_code = Spear.Grpc.Response.status_code(code)

    {:error,
     %Spear.Grpc.Response{
       status_code: status_code,
       status: Spear.Grpc.Response.map_status(status_code),
       message: message
     }}
  end

  defp map_revision(
         {:success, Streams.batch_append_resp_success(current_revision_option: revision)}
       ),
       do: map_revision(revision)

  defp map_revision({:current_revision, revision}), do: revision
  # coveralls-ignore-start
  defp map_revision({:empty, Google.empty()}), do: :empty
  # coveralls-ignore-stop
  defp map_revision(_), do: nil

  defp map_position({:success, Streams.batch_append_resp_success(position_option: position)}),
    do: map_position(position)

  defp map_position({:position, position}), do: Spear.Position.from_record(position)
  # coveralls-ignore-start
  defp map_position({:empty, Google.empty()}), do: :empty
  # coveralls-ignore-stop
  defp map_position(_), do: nil
end
