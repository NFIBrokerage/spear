make_server = fn ->
  {:ok, pid} = Spear.Connection.start_link(connection_string: "esdb://localhost:2113")

  pid
end

conn = make_server.()

# subscribe = fn ->
#   import Spear.Filter
#
#   Spear.subscribe(conn, self(), :all, filter: ~f/grpc-/pt)
# end
