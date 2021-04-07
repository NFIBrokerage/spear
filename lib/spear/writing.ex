defmodule Spear.Writing do
  @moduledoc false

  # Helper functions for writing (appending) events to the EventStore

  alias Spear.Protos.EventStore.Client.{
    Streams.Streams.Service,
    Streams.AppendReq,
    Streams.AppendResp,
    Streams.DeleteReq,
    Streams.TombstoneReq,
    Shared
  }

  alias Spear.ExpectationViolation

  def build_write_request(params) do
    messages =
      [build_append_request(params)]
      |> Stream.concat(params.event_stream)
      |> Stream.map(&to_append_request/1)

    %Spear.Request{
      service: Service,
      rpc: :Append,
      messages: messages
    }
    |> Spear.Request.expand()
  end

  defp build_append_request(params) do
    %AppendReq{
      content:
        {:options,
         %AppendReq.Options{
           expected_stream_revision: map_expectation(params.expect),
           stream_identifier: %Shared.StreamIdentifier{
             streamName: params.stream
           }
         }}
    }
  end

  def build_delete_request(%{tombstone?: false} = params) do
    %Spear.Request{
      service: Service,
      rpc: :Delete,
      messages: [build_delete_message(params)]
    }
    |> Spear.Request.expand()
  end

  def build_delete_request(%{tombstone?: true} = params) do
    %Spear.Request{
      service: Service,
      rpc: :Tombstone,
      messages: [build_delete_message(params)]
    }
    |> Spear.Request.expand()
  end

  defp build_delete_message(%{tombstone?: false} = params) do
    %DeleteReq{
      options: %DeleteReq.Options{
        stream_identifier: %Shared.StreamIdentifier{streamName: params.stream},
        expected_stream_revision: map_expectation(params.expect)
      }
    }
  end

  defp build_delete_message(%{tombstone?: true} = params) do
    %TombstoneReq{
      options: %TombstoneReq.Options{
        stream_identifier: %Shared.StreamIdentifier{streamName: params.stream},
        expected_stream_revision: map_expectation(params.expect)
      }
    }
  end

  defp map_expectation(revision) when is_integer(revision) and revision >= 1,
    do: {:revision, revision}

  defp map_expectation(:empty), do: {:no_stream, %Shared.Empty{}}
  defp map_expectation(:exists), do: {:stream_exists, %Shared.Empty{}}
  defp map_expectation(_), do: {:any, %Shared.Empty{}}

  defp to_append_request(%Spear.Event{} = event) do
    Spear.Event.to_proposed_message(event)
  end

  defp to_append_request(%AppendReq{} = request), do: request

  # N.B. there are fields in here
  # - current_revision_option_20_6_0
  # - expected_revision_option_20_6_0
  # that I'm not really sure what to do with
  def map_expectation_violation(%AppendResp.WrongExpectedVersion{
        current_revision_option: current_revision,
        expected_revision_option: expected_revision
      }) do
    %ExpectationViolation{
      current: map_current_revision(current_revision),
      expected: map_expected_revision(expected_revision)
    }
  end

  defp map_current_revision({:current_revision, revision}), do: revision
  defp map_current_revision({:current_no_stream, %Shared.Empty{}}), do: :empty

  defp map_expected_revision({:expected_no_stream, %Shared.Empty{}}), do: :empty
  defp map_expected_revision({:expected_stream_exists, %Shared.Empty{}}), do: :exists
  defp map_expected_revision({:expected_revision, revision}), do: revision
  # shouldn't this be unreachable?!?
  defp map_expected_revision({:expected_any, %Shared.Empty{}}), do: :any
end
