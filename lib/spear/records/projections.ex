defmodule Spear.Records.Projections do
  require Spear.Records

  @moduledoc """
  A record macro interface for interacting with the EventStoreDB Projections API
  """

  Spear.Records.from_hrl(:spear_proto_projections)
end
