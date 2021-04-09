defmodule Spear.Contracts.Mint do
  @moduledoc false

  # A behaviour for Mint so we can use Mint with Mox

  alias Mint.{Types, HTTP2}

  @type conn :: HTTP2.t()

  @callback connect(Types.scheme(), Types.address(), :inets.port_number(), Keyword.t()) ::
              {:ok, conn()} | {:error, Types.error()}

  @callback cancel_request(conn(), Types.request_ref()) ::
              {:ok, conn()} | {:error, conn(), Types.error()}

  @callback close(conn()) :: {:ok, conn()}

  @callback request(conn(), String.t(), String.t(), Types.headers(), :stream) ::
              {:ok, conn(), Types.request_ref()} | {:error, conn(), Types.error()}

  @callback stream(conn(), term()) ::
              :unknown
              | {:ok, conn(), [Types.response()]}
              | {:error, conn(), Types.error(), [Types.response()]}

  @callback stream_request_body(conn(), Types.request_ref(), iodata() | :eof) ::
              {:ok, conn()} | {:error, conn(), Types.error()}

  @callback get_window_size(conn(), :connection | {:request, Types.request_ref()}) ::
              non_neg_integer()
end
