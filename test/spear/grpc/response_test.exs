defmodule Spear.Grpc.ResponseTest do
  use ExUnit.Case, async: true

  # note that these tests are a bit un-ideal: I'd rather have a little http(2)
  # server included in the test suite to bounce these requests off of and get
  # real responses, but the test noise just from the EventStoreDB server is
  # already very unstable, so just gonna do some very simple units to get
  # coverage

  alias Spear.{Grpc, Connection}
  alias Spear.Protos.EventStore.Client.Streams.ReadResp

  test "a non-200 status code connection response is converted to an error code 2" do
    grpc_response =
      %Connection.Response{status: 404, headers: []}
      |> Grpc.Response.from_connection_response()

    assert grpc_response.status_code == 2
    assert grpc_response.status == :unknown
    assert grpc_response.message =~ "Bad HTTP status code"
    assert grpc_response.message =~ "404"
  end

  test "a malformed data buffer results in a code 13" do
    # what's the chance this comes out to a valid ReadResp? hehe
    buffer = :crypto.strong_rand_bytes(64)

    grpc_response =
      %Connection.Response{status: 200, headers: [], type: ReadResp, data: buffer}
      |> Grpc.Response.from_connection_response()

    assert grpc_response.status_code == 13
    assert grpc_response.status == :internal
    assert grpc_response.message =~ "Error parsing response proto"
  end
end
