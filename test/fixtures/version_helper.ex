defmodule VersionHelper do
  @moduledoc """
  Provides a function that tags tests depending on their compatibilty with the
  EventStoreDB version declared in the env
  """

  version =
    case System.get_env("EVENTSTORE_VERSION") do
      nil -> :error
      version -> {:ok, version}
    end

  version =
    with {:ok, version} <- version,
         [capture] <- Regex.run(~r"\d[\d\.]+", version) do
      capture
    else
      nil ->
        # if the regex doesn't match then we're using the CI/nightly image
        :nightly

      :error ->
        raise "Could not parse the eventstore version! Set the EVENTSTORE_VERSION environment variable."
    end

  @version version

  def compatible(pattern) do
    # we get some "warning: this check/guard will always yield the same result"s
    # on old elixir versions if we don't do this because the compiler is too
    # smart for its own good :P
    version = @version

    cond do
      pattern == :nightly and version == :nightly ->
        :version_compatible

      not is_binary(pattern) ->
        :version_incompatible

      version == :nightly ->
        :version_compatible

      Version.match?(version, pattern) ->
        :version_compatible

      true ->
        :version_incompatible
    end
  end
end
