defmodule Spear.User do
  @moduledoc """
  A struct representing an EventStoreDB user

  These are returned from `Spear.user_details/3`.
  """
  @moduledoc since: "0.3.0"

  import Spear.Records.Users,
    only: [
      details_resp: 1,
      details_resp_user_details: 1,
      details_resp_user_details_date_time: 1
    ]

  @typedoc """
  A struct representing an EventStoreDB user

  The `:enabled?` flag controls whether or not a user may execute requests,
  even with valid login information. This can be used to temporarily disable
  a user as an alternative to deleting the user altogether.

  ## Examples

      iex> Spear.create_user(conn, "Aladdin", "aladdin", "open sesame", ["$ops"])
      :ok
      iex> Spear.user_details(conn, "aladdin")
      {:ok,
       %Spear.User{
         enabled?: true,
         full_name: "Aladdin",
         groups: ["$ops"],
         last_updated: ~U[2021-04-18 16:48:38.583313Z],
         login_name: "aladdin"
       }}
  """
  @typedoc since: "0.3.0"
  @type t :: %__MODULE__{
          login_name: String.t(),
          full_name: String.t(),
          groups: [String.t()],
          last_updated: DateTime.t(),
          enabled?: boolean()
        }

  defstruct ~w[login_name full_name groups last_updated enabled?]a

  def from_details_resp(
        details_resp(
          user_details:
            details_resp_user_details(
              login_name: login_name,
              full_name: full_name,
              groups: groups,
              last_updated:
                details_resp_user_details_date_time(ticks_since_epoch: ticks_since_epoch),
              disabled: disabled?
            )
        )
      ) do
    last_updated =
      case Spear.parse_stamp(ticks_since_epoch) do
        {:ok, datetime} ->
          datetime

        # coveralls-ignore-start
        _ ->
          nil
          # coveralls-ignore-stop
      end

    %__MODULE__{
      login_name: login_name,
      full_name: full_name,
      groups: groups,
      last_updated: last_updated,
      enabled?: not disabled?
    }
  end
end
