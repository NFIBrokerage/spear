defmodule Spear.Acl do
  @moduledoc """
  A struct representing an access control list (ACL)

  See the [Security guide](guides/security.md) for more information on ACLs
  """

  @typedoc """
  An access control list (ACL) type

  See the [Security guide](guides/security.md) for more information on ACLs

  ACLs may provide permissions for a single user/group or a list of
  user/groups.

  ## Examples

      iex> Spear.Acl.allow_all()
      %Spear.Acl{
        delete: "$all",
        metadata_read: "$all",
        metadata_write: "$all",
        read: "$all",
        write: "$all"
      }
  """
  @typedoc since: "1.3.0"
  @type t :: %__MODULE__{
          read: String.t() | [String.t()],
          write: String.t() | [String.t()],
          delete: String.t() | [String.t()],
          metadata_read: String.t() | [String.t()],
          metadata_write: String.t() | [String.t()]
        }

  @fields ~w[read write delete metadata_read metadata_write]a

  defstruct @fields

  @doc """
  Produces an ACL that allows all users access to all resources

  Note that clients that do not provide credentials at all fall under the
  `$all` group.

  ## Examples

      iex> Spear.Acl.allow_all()
      %Spear.Acl{
        delete: "$all",
        metadata_read: "$all",
        metadata_write: "$all",
        read: "$all",
        write: "$all"
      }
  """
  def allow_all do
    struct(__MODULE__, Enum.zip(@fields, Stream.repeatedly(fn -> "$all" end)))
  end

  @doc """
  Produces an ACL that only allows access to all resources to the `$admins`
  group

  ## Examples

      iex> Spear.Acl.admins_only()
      %Spear.Acl{
        delete: "$admins",
        metadata_read: "$admins",
        metadata_write: "$admins",
        read: "$admins",
        write: "$admins"
      }
  """
  def admins_only do
    struct(__MODULE__, Enum.zip(@fields, Stream.repeatedly(fn -> "$admins" end)))
  end

  @doc """
  Converts an ACL struct to a map with the keys expected by the EventStoreDB

  This function is used internall by `Spear.set_global_acl/4` to create a
  global ACL event body, but may be used to create an acl body on its own.

  ## Examples

      iex> Spear.Acl.allow_all() |> Spear.Acl.to_map()
      %{
        "$w" => "$all",
        "$r" => "$all",
        "$d" => "$all",
        "$mw" => "$all",
        "$mr" => "$all"
      }
  """
  @doc since: "0.1.3"
  @spec to_map(t()) :: %{String.t() => String.t() | [String.t()]}
  def to_map(%__MODULE__{} = acl) do
    %{
      "$w" => acl.write,
      "$r" => acl.read,
      "$d" => acl.delete,
      "$mw" => acl.metadata_write,
      "$mr" => acl.metadata_read
    }
    |> Enum.reject(fn {_k, v} -> v == nil end)
    |> Enum.into(%{})
  end

  @doc false
  def from_map(%{} = acl) do
    %__MODULE__{
      read: Map.get(acl, "$r"),
      write: Map.get(acl, "$w"),
      delete: Map.get(acl, "$d"),
      metadata_read: Map.get(acl, "$mr"),
      metadata_write: Map.get(acl, "$mw")
    }
  end
end
