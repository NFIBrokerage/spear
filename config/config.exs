import Config

config :spear, :mint, Spear.Adapters.Mint

import_config "#{config_env()}.exs"
