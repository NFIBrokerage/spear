defmodule Spear.Writing do
  @moduledoc false

  # Helper functions for writing (appending) events to the EventStoreDB

  import Spear.Records.Streams,
    only: [
      append_req: 0,
      append_req: 1,
      append_req_options: 1,
      append_resp_wrong_expected_version: 1,
      delete_req: 1,
      delete_req_options: 1,
      tombstone_req: 1,
      tombstone_req_options: 1,
      batch_append_req: 1,
      batch_append_req_options: 1,
      batch_append_req_proposed_message: 0
    ]

  import Spear.Records.Shared,
    only: [
      stream_identifier: 1,
      empty: 0,
      uuid: 1
    ]

  require Spear.Records.Google, as: Google

  alias Spear.ExpectationViolation

  def build_append_request(params) do
    append_req(
      content:
        {:options,
         append_req_options(
           expected_stream_revision: map_expectation(params.expect),
           stream_identifier: stream_identifier(stream_name: params.stream)
         )}
    )
  end

  def build_delete_request(%{tombstone?: false} = params) do
    delete_req(
      options:
        delete_req_options(
          stream_identifier: stream_identifier(stream_name: params.stream),
          expected_stream_revision: map_expectation(params.expect)
        )
    )
  end

  def build_delete_request(%{tombstone?: true} = params) do
    tombstone_req(
      options:
        tombstone_req_options(
          stream_identifier: stream_identifier(stream_name: params.stream),
          expected_stream_revision: map_expectation(params.expect)
        )
    )
  end

  def build_batch_append_request(params) do
    batch_append_req(
      correlation_id: uuid(value: {:string, params.batch_id}),
      options: map_batch_append_options(params),
      proposed_messages: Enum.map(params.events, &map_batch_append_messages/1),
      is_final: params.done?
    )
  end

  defp map_expectation(revision) when is_integer(revision) and revision >= 0,
    do: {:revision, revision}

  defp map_expectation(:empty), do: {:no_stream, empty()}
  defp map_expectation(:exists), do: {:stream_exists, empty()}
  defp map_expectation(_), do: {:any, empty()}

  def to_append_request(%Spear.Event{} = event) do
    Spear.Event.to_proposed_message(event)
  end

  def to_append_request(append_req() = request), do: request

  # N.B. there are fields in here
  # - current_revision_option_20_6_0
  # - expected_revision_option_20_6_0
  # that I'm not really sure what to do with
  def map_expectation_violation(
        append_resp_wrong_expected_version(
          current_revision_option: current_revision,
          expected_revision_option: expected_revision
        )
      ) do
    %ExpectationViolation{
      current: map_current_revision(current_revision),
      expected: map_expected_revision(expected_revision)
    }
  end

  defp map_current_revision({:current_revision, revision}), do: revision
  defp map_current_revision({:current_no_stream, empty()}), do: :empty

  defp map_expected_revision({:expected_no_stream, empty()}), do: :empty
  defp map_expected_revision({:expected_stream_exists, empty()}), do: :exists
  defp map_expected_revision({:expected_revision, revision}), do: revision
  # shouldn't this be unreachable?!?
  defp map_expected_revision({:expected_any, empty()}), do: :any

  def build_global_acl_event(%Spear.Acl{} = user_acl, %Spear.Acl{} = system_acl, json_encode!)
      when is_function(json_encode!, 1) do
    Spear.Event.new(
      "update-default-acl",
      %{
        "$userStreamAcl" => Spear.Acl.to_map(user_acl),
        "$systemStreamAcl" => Spear.Acl.to_map(system_acl)
      }
      |> json_encode!.(),
      content_type: "application/vnd.eventstore.events+json"
    )
  end

  defp map_batch_append_options(%{continuation?: true}), do: :undefined

  defp map_batch_append_options(params) do
    batch_append_req_options(
      stream_identifier: stream_identifier(stream_name: params.stream_name),
      expected_stream_position: map_expected_position(params.expect),
      deadline_option: map_deadline(params.deadline)
    )
  end

  defp map_deadline(nil), do: :undefined
  # coveralls-ignore-start
  defp map_deadline({:duration, seconds, nanos}),
    do: {:deadline, Google.duration(seconds, nanos)}

  defp map_deadline(timestamp), do: {:deadline_21_10_0, Google.timestamp(timestamp)}
  # coveralls-ignore-stop

  defp map_expected_position(revision) when is_integer(revision) and revision >= 0,
    do: {:stream_position, revision}

  defp map_expected_position(:empty), do: {:no_stream, Google.empty()}
  defp map_expected_position(:exists), do: {:stream_exists, Google.empty()}
  defp map_expected_position(:any), do: {:any, Google.empty()}

  # coveralls-ignore-start
  defp map_batch_append_messages(batch_append_req_proposed_message() = message) do
    message
  end

  # coveralls-ignore-stop

  defp map_batch_append_messages(%Spear.Event{} = event) do
    Spear.Event.to_proposed_message(
      event,
      %{"application/json" => &Jason.encode!/1},
      :batch_append
    )
  end
end
