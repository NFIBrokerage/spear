defmodule Spear.TypedMessage do
  @moduledoc false
  # a behaviour which forces a message_type/0 function
  # this message type is added as a header so that
  # networking systems and tools like istio or wireshark can
  # automatically detect the message type being sent
  # (this is not possible without prior knowledge of the protos
  # or this message-type header)

  @callback message_type :: String.t()
end
