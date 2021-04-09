defmodule Spear.Adapters.Mint do
  @moduledoc false

  @behaviour Spear.Contracts.Mint

  alias Mint.{HTTP, HTTP2}

  # coveralls-ignore-start
  @impl Spear.Contracts.Mint
  defdelegate connect(scheme, address, port, opts), to: HTTP

  @impl Spear.Contracts.Mint
  defdelegate cancel_request(conn, request_ref), to: HTTP2

  @impl Spear.Contracts.Mint
  defdelegate close(conn), to: HTTP2

  @impl Spear.Contracts.Mint
  defdelegate request(conn, method, path, headers, body), to: HTTP2

  @impl Spear.Contracts.Mint
  defdelegate stream(conn, message), to: HTTP2

  @impl Spear.Contracts.Mint
  defdelegate stream_request_body(conn, request_ref, chunk), to: HTTP2

  @impl Spear.Contracts.Mint
  defdelegate get_window_size(conn, connection_or_request), to: HTTP2

  # coveralls-ignore-stop
end
