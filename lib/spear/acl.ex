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
end
