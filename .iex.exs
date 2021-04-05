make_server = fn ->
  {:ok, pid} = Spear.Connection.start_link(connection_string: "http://localhost:2113")

  pid
end
