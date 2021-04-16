defmodule Spear.Connection.Configuration do
  @moduledoc """
  Configuration for `Spear.Connection`s

  ## Options

  TODO
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
          errors: Keyword.t()
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
            errors: []

  @doc """
  Parses configuration from a keyword list
  """
  @doc since: "0.2.0"
  @spec new(Keyword.t()) :: t()
  def new(opts) when is_list(opts) do
    config =
      opts
      |> Keyword.get(:connection_string)
      |> from_connection_string()
      |> Keyword.merge(opts)

    struct(__MODULE__, config)
    |> validate()
  end

  defp from_connection_string(connection_string) when is_binary(connection_string) do
    uri = parse_uri(connection_string)
    tls? = tls?(uri)
    {username, password} = parse_credentials(uri)

    [
      scheme: if(tls?, do: :https, else: :http),
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

  defp validate({:scheme = key, value}, errors) when value not in [:http, :https] do
    [{key, "scheme #{inspect(value)} must be :http or :https"} | errors]
  end

  defp validate({_k, _v}, errors), do: errors
end
