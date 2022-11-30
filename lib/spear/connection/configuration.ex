defmodule Spear.Connection.Configuration do
  @default_mint_opts [protocols: [:http2], mode: :active]
  @moduledoc """
  Configuration for `Spear.Connection`s

  ## Options

  * `:name` - the name of the GenServer. See `t:GenServer.name/0` for more
    information. When not provided, the spawned process is not aliased to a
    name and is only addressable through its PID.

  * `:connection_string` - the connection string to parse
    containing all connection information. Other options like `:host` or
    `:port` will be parsed from the connection string. If options parsed from
    the connection string are passed, they will be treated as overrides to the
    value found in the connection string. Consult the EventStoreDB
    documentation for formulating a valid connection string.

  * `:mint_opts` - (default: `#{inspect(@default_mint_opts)}`) a keyword
    list of options to pass to mint. The default values cannot be overridden.
    This can be useful for configuring TLS. See the
    [security guide](guides/security.md) for more information.

  * `:host` - (default: `"localhost"`) the host address of the EventStoreDB

  * `:port` - (default: `2113`) the external gRPC port of the EventStoreDB

  * `:tls?` - (default: `false`) whether or not to use TLS to secure the
    connection to the EventStoreDB

  * `:username` - (default: `"admin"`) the user to connect as

  * `:password` - (default: `"changeit"`) the user's password

  * `:keep_alive_interval` - (default: `10_000`ms - 10s) the period to send
    keep-alive pings to the EventStoreDB. Set `-1` to disable keep-alive
    checks. Should be any integer value `>= 10_000`. This option can be used
    in conjunction with `:keep_alive_timeout` to properly disconnect if the
    EventStoreDB is not responding to network traffic.

  * `:keep_alive_timeout` - (default: `10_000`ms - 10s) the time after sending
    a keep-alive ping when the ping will be considered unacknowledged. Used
    in conjunction with `:keep_alive_interval`. Set to `-1` to disable
    keep-alive checks. Should be any integer value `>= 10_000`.

  * `:read_only?` - (default: `false`) controls whether the connection should
    be limited to read-only functionality. The list of read-only APIs can be
    queried with `Spear.Connection.read_apis/0`

  See the `Spear.Connection` module docs for more information about keep-alive.
  """
  @moduledoc since: "0.2.0"

  require Logger

  # ms
  @default_keepalive 10_000

  @typedoc """
  Configuration for a `Spear.Connection`.
  """
  @typedoc since: "0.2.0"
  @type t :: %__MODULE__{
          scheme: :http | :https,
          host: Mint.Types.address(),
          port: :inet.port_number(),
          tls?: boolean(),
          username: String.t() | nil,
          password: String.t() | nil,
          keep_alive_interval: pos_integer() | false,
          keep_alive_timeout: pos_integer() | false,
          mint_opts: Keyword.t(),
          valid?: boolean(),
          errors: Keyword.t(),
          read_only?: boolean(),
          register_with: %{registry: atom(), key: atom(), value: term() | nil} | nil
        }

  defstruct scheme: :http,
            host: "localhost",
            port: 2113,
            tls?: false,
            username: "admin",
            password: "changeit",
            keep_alive_interval: 10_000,
            keep_alive_timeout: 10_000,
            mint_opts: [],
            valid?: true,
            errors: [],
            read_only?: false,
            register_with: nil

  @doc false
  def credentials(%__MODULE__{username: username, password: password}) do
    {username, password}
  end

  @doc """
  Parses configuration from a keyword list

  This function is used internally by `Spear.Connection` when connecting.
  """
  @doc since: "0.2.0"
  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    config =
      opts
      |> Keyword.get(:connection_string)
      |> from_connection_string()
      |> Keyword.merge(opts)
      |> override_mint_opts()
      |> set_scheme()

    struct(__MODULE__, config)
    |> validate()
  end

  defp from_connection_string(connection_string) when is_binary(connection_string) do
    uri = parse_uri(connection_string)
    tls? = tls?(uri)
    {username, password} = parse_credentials(uri)

    [
      host: uri.host,
      port: uri.port,
      tls?: tls?,
      username: username,
      password: password,
      keep_alive_interval: keep_alive_interval(uri),
      keep_alive_timeout: keep_alive_timeout(uri)
    ]
  end

  defp from_connection_string(_), do: []

  defp parse_uri(connection_string) do
    uri = URI.parse(connection_string)

    %URI{uri | query: URI.decode_query(uri.query || "")}
  end

  defp tls?(%URI{query: %{"tls" => "true"}}), do: true
  defp tls?(_), do: false

  defp keep_alive_interval(uri), do: keep_alive_value(uri, "keepAliveInterval")
  defp keep_alive_timeout(uri), do: keep_alive_value(uri, "keepAliveTimeout")

  defp keep_alive_value(uri, key) do
    with {:ok, value_str} <- Map.fetch(uri.query, key),
         {value, ""} <- Integer.parse(value_str),
         value when value >= @default_keepalive <- value do
      value
    else
      -1 ->
        false

      value when value in 0..@default_keepalive ->
        Logger.warn("Specified #{key} of #{value} is less than recommended 10_000ms")

        value

      value when is_integer(value) and value < -1 ->
        # will get picked up by validation
        value

      _ ->
        @default_keepalive
    end
  end

  defp parse_credentials(uri) do
    with userinfo when is_binary(userinfo) <- uri.userinfo,
         [username, password] <- String.split(userinfo, ":") do
      {username, password}
    else
      _ -> {nil, nil}
    end
  end

  defp override_mint_opts(opts) do
    mint_opts =
      opts
      |> Keyword.get(:mint_opts, [])
      |> Keyword.merge(@default_mint_opts)

    Keyword.merge(opts, mint_opts: mint_opts)
  end

  defp set_scheme(opts) do
    Keyword.put(opts, :scheme, if(opts[:tls?], do: :https, else: :http))
  end

  defp validate(%__MODULE__{} = config) do
    errors =
      config
      |> Map.from_struct()
      |> Enum.reduce([], &validate/2)

    %__MODULE__{config | errors: errors, valid?: errors == []}
  end

  defp validate({:keep_alive_interval = key, value}, errors)
       when is_integer(value) and value <= 0 do
    [{key, "keepAliveInterval must be greater than 1"} | errors]
  end

  defp validate({:keep_alive_timeout = key, value}, errors)
       when is_integer(value) and value <= 0 do
    [{key, "keepAliveTimeout must be greater than 1"} | errors]
  end

  defp validate({:port = key, value}, errors)
       when not is_integer(value) or value not in 1..65_535 do
    [{key, "#{inspect(value)} is not a valid port number"} | errors]
  end

  defp validate({_k, _v}, errors), do: errors
end
