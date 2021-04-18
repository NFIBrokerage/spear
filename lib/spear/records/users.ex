defmodule Spear.Records.Users do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Users API
  """

  Spear.Records.from_hrl(:spear_proto_users)
end
