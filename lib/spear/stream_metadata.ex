defmodule Spear.StreamMetadata do
  @moduledoc """
  A struct for describing the metadata about a stream
  """

  @reserved_keys ~w[$maxAge $tb $cacheControl $maxCount $acl]

  @typedoc """
  Internal and custom metadata about a stream

  See the EventStoreDB stream metadata documentation for more details.
  """
  @typedoc since: "0.1.3"
  @type t :: %__MODULE__{
    max_age: pos_integer() | nil,
    truncate_before: pos_integer() | nil,
    cache_control: pos_integer() | nil,
    max_count: pos_integer() | nil,
    acl: Spear.Acl.t() | nil,
    custom: %{String.t() => any()} | nil
  }

  defstruct [:max_age, :truncate_before, :cache_control, :max_count, :acl, :custom]

  @doc """
  Converts a stream metadata struct to a map in the format EventStoreDB expects
  """
  def to_map(%__MODULE__{} = metadata) do
    %{
      "$maxAge" => metadata.max_age,
      "$tb" => metadata.truncate_before,
      "$cacheControl" => metadata.cache_control,
      "$maxCount" => metadata.max_count,
      "$acl" => metadata.acl && Spear.Acl.to_map(metadata.acl)
    }
    |> Map.merge(metadata.custom || %{})
    |> Enum.reject(fn {_k, v} -> v in [nil, %{}] end)
    |> Enum.into(%{})
  end

  @doc false
  def from_spear_event(%Spear.Event{type: "$metadata"} = event) do
    %__MODULE__{
      max_age: Map.get(event.body, "$maxAge"),
      truncate_before: Map.get(event.body, "$tb"),
      cache_control: Map.get(event.body, "$cacheControl"),
      max_count: Map.get(event.body, "$cacheControl"),
      acl: Map.get(event.body, "$acl", %{}) |> Spear.Acl.from_map(),
      custom: Map.drop(event.body, @reserved_keys)
    }
  end
end
