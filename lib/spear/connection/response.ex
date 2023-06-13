defmodule Spear.Connection.Response do
  @moduledoc false

  # a slim data structure for storing information about an HTTP/2 response

  @type t :: %__MODULE__{
          status: Mint.Types.status(),
          type: {module(), atom()},
          headers: Mint.Types.headers(),
          data: binary()
        }

  defstruct [:status, :type, headers: [], data: <<>>]
end
