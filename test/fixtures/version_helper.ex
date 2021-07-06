defmodule VersionHelper do
  @moduledoc """
  Provides a function that tags tests depending on their compatibilty with the
  EventStoreDB version declared in the env
  """

  @version System.get_env("EVENTSTORE_VERSION")

  def compatible(pattern) do
    if Version.match?(@version, pattern) do
      :version_compatible
    else
      :version_incompatible
    end
  end
end
