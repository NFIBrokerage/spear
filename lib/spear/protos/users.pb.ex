defmodule EventStore.Client.Users.CreateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t(),
          password: String.t(),
          full_name: String.t(),
          groups: [String.t()]
        }

  defstruct [:login_name, :password, :full_name, :groups]

  field :login_name, 1, type: :string
  field :password, 2, type: :string
  field :full_name, 3, type: :string
  field :groups, 4, repeated: true, type: :string
end

defmodule EventStore.Client.Users.CreateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.CreateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.CreateReq.Options
end

defmodule EventStore.Client.Users.CreateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.UpdateReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t(),
          password: String.t(),
          full_name: String.t(),
          groups: [String.t()]
        }

  defstruct [:login_name, :password, :full_name, :groups]

  field :login_name, 1, type: :string
  field :password, 2, type: :string
  field :full_name, 3, type: :string
  field :groups, 4, repeated: true, type: :string
end

defmodule EventStore.Client.Users.UpdateReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.UpdateReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.UpdateReq.Options
end

defmodule EventStore.Client.Users.UpdateResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.DeleteReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t()
        }

  defstruct [:login_name]

  field :login_name, 1, type: :string
end

defmodule EventStore.Client.Users.DeleteReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.DeleteReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.DeleteReq.Options
end

defmodule EventStore.Client.Users.DeleteResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.EnableReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t()
        }

  defstruct [:login_name]

  field :login_name, 1, type: :string
end

defmodule EventStore.Client.Users.EnableReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.EnableReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.EnableReq.Options
end

defmodule EventStore.Client.Users.EnableResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.DisableReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t()
        }

  defstruct [:login_name]

  field :login_name, 1, type: :string
end

defmodule EventStore.Client.Users.DisableReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.DisableReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.DisableReq.Options
end

defmodule EventStore.Client.Users.DisableResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.DetailsReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t()
        }

  defstruct [:login_name]

  field :login_name, 1, type: :string
end

defmodule EventStore.Client.Users.DetailsReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.DetailsReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.DetailsReq.Options
end

defmodule EventStore.Client.Users.DetailsResp.UserDetails.DateTime do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          ticks_since_epoch: integer
        }

  defstruct [:ticks_since_epoch]

  field :ticks_since_epoch, 1, type: :int64
end

defmodule EventStore.Client.Users.DetailsResp.UserDetails do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t(),
          full_name: String.t(),
          groups: [String.t()],
          last_updated: EventStore.Client.Users.DetailsResp.UserDetails.DateTime.t() | nil,
          disabled: boolean
        }

  defstruct [:login_name, :full_name, :groups, :last_updated, :disabled]

  field :login_name, 1, type: :string
  field :full_name, 2, type: :string
  field :groups, 3, repeated: true, type: :string
  field :last_updated, 4, type: EventStore.Client.Users.DetailsResp.UserDetails.DateTime
  field :disabled, 5, type: :bool
end

defmodule EventStore.Client.Users.DetailsResp do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          user_details: EventStore.Client.Users.DetailsResp.UserDetails.t() | nil
        }

  defstruct [:user_details]

  field :user_details, 1, type: EventStore.Client.Users.DetailsResp.UserDetails
end

defmodule EventStore.Client.Users.ChangePasswordReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t(),
          current_password: String.t(),
          new_password: String.t()
        }

  defstruct [:login_name, :current_password, :new_password]

  field :login_name, 1, type: :string
  field :current_password, 2, type: :string
  field :new_password, 3, type: :string
end

defmodule EventStore.Client.Users.ChangePasswordReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.ChangePasswordReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.ChangePasswordReq.Options
end

defmodule EventStore.Client.Users.ChangePasswordResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.ResetPasswordReq.Options do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          login_name: String.t(),
          new_password: String.t()
        }

  defstruct [:login_name, :new_password]

  field :login_name, 1, type: :string
  field :new_password, 2, type: :string
end

defmodule EventStore.Client.Users.ResetPasswordReq do
  @moduledoc false
  use Protobuf, syntax: :proto3

  @type t :: %__MODULE__{
          options: EventStore.Client.Users.ResetPasswordReq.Options.t() | nil
        }

  defstruct [:options]

  field :options, 1, type: EventStore.Client.Users.ResetPasswordReq.Options
end

defmodule EventStore.Client.Users.ResetPasswordResp do
  @moduledoc false
  use Protobuf, syntax: :proto3
  @type t :: %__MODULE__{}

  defstruct []
end

defmodule EventStore.Client.Users.Users.Service do
  @moduledoc false
  use Spear.Service, name: "event_store.client.users.Users"

  rpc :Create, EventStore.Client.Users.CreateReq, EventStore.Client.Users.CreateResp

  rpc :Update, EventStore.Client.Users.UpdateReq, EventStore.Client.Users.UpdateResp

  rpc :Delete, EventStore.Client.Users.DeleteReq, EventStore.Client.Users.DeleteResp

  rpc :Disable, EventStore.Client.Users.DisableReq, EventStore.Client.Users.DisableResp

  rpc :Enable, EventStore.Client.Users.EnableReq, EventStore.Client.Users.EnableResp

  rpc :Details, EventStore.Client.Users.DetailsReq, stream(EventStore.Client.Users.DetailsResp)

  rpc :ChangePassword,
      EventStore.Client.Users.ChangePasswordReq,
      EventStore.Client.Users.ChangePasswordResp

  rpc :ResetPassword,
      EventStore.Client.Users.ResetPasswordReq,
      EventStore.Client.Users.ResetPasswordResp
end
