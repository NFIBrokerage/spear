defmodule Spear.Writing do
  @moduledoc false

  # Helper functions for writing (appending) events to the EventStore

  alias Spear.Protos.EventStore.Client.{
    Streams.Streams.Service,
    Streams.AppendReq,
    Streams.AppendResp,
    Shared
  }

  alias Spear.ExpectationViolation

  def build_write_request(events, stream_name, opts) do
    {expectation, opts} = Keyword.pop(opts, :expect, :any)

    messages =
      stream_name
      |> build_append_request(expectation)
      |> List.wrap()
      |> Stream.concat(events)
      |> Stream.map(&to_append_request/1)

    %Spear.Request{
      service: Service,
      rpc: :Append,
      messages: messages,
      batch_size: opts[:batch_size]
    }
    |> Spear.Request.expand()
  end

  defp build_append_request(stream_name, expectation) do
    %AppendReq{
      content:
        {:options,
         %AppendReq.Options{
           expected_stream_revision: map_expectation(expectation),
           stream_identifier: %Shared.StreamIdentifier{
             streamName: stream_name
           }
         }}
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

  def decode_append_response(buffer, _raw? = false) when is_binary(buffer) do
    with {_, {%AppendResp{} = response, <<>>}} <-
           {:decode, Spear.Grpc.decode_next_message(buffer, AppendResp)},
         %AppendResp{result: {:success, _metadata = %AppendResp.Success{}}} <- response do
      :ok
    else
      %AppendResp{result: {:wrong_expected_version, expectation_violation}} ->
        {:error, map_expectation_violation(expectation_violation)}
    end
  end

  # N.B. there are fields in here
  # - current_revision_option_20_6_0
  # - expected_revision_option_20_6_0
  # that I'm not really sure what to do with
  defp map_expectation_violation(%AppendResp.WrongExpectedVersion{
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
