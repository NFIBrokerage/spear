defmodule Spear.Records do
  @moduledoc false

  @callback service_module() :: module()
  @callback service() :: atom()

  @prefix :event_store_db_gpb_protobufs_

  @doc """
  a macro that extracts all records from the gpb generated .hrl files in src/

  it turns them into little macros with Record.defrecord/2
  so they are easier to use/match-with in other files in Spear

  if you see other stuff in spear like

      iex> import Spear.Records.Streams
      iex> match?(read_resp(content: {:checkpoint, _}), {:"event_store.client.streams.ReadResp", content: {:checkpoint, ..}})
      true

  this is where that comes from!
  """
  defmacro __using__(service_module: service_module) do
    service_module = String.to_atom("#{@prefix}#{service_module}")

    quote do
      require Record

      @behaviour unquote(__MODULE__)

      prefix = (unquote(service_module).get_package_name() |> Atom.to_string()) <> "."

      record_path =
        Path.join(["event_store_db_gpb_protobufs", "include", "#{unquote(service_module)}.hrl"])

      records =
        Record.extract_all(from_lib: record_path)
        |> Enum.map(fn {name, attrs} -> {name, Atom.to_string(name), attrs} end)
        |> Enum.filter(fn {_name, string_name, _attrs} ->
          String.starts_with?(string_name, prefix)
        end)
        |> Enum.map(&unquote(__MODULE__).with_short_name(&1, prefix))

      for {name, short_name, attrs} <- records do
        Record.defrecord(short_name, name, attrs)
      end

      @doc """
      Returns the `:gpb`-generated service module
      """
      @impl unquote(__MODULE__)
      def service_module, do: unquote(service_module)

      @doc """
      Returns the gRPC service name for the API
      """
      @impl unquote(__MODULE__)
      def service, do: service_module().get_service_names() |> List.first()
    end
  end

  def with_short_name({name, string_name, attrs}, prefix) do
    {name, to_short_name(string_name, prefix), attrs}
  end

  @doc """
  provides a short name for a protobuf message name usable as a function

      iex> to_short_name("event_store.clients.streams.ReadResp", "event_store.clients.streams.")
      :read_resp
      iex> to_short_name("event_store.clients.streams.ReadResp.ReadEvent", "event_store.clients.streams.")
      :read_resp_read_event
  """
  def to_short_name(string_name, prefix) do
    string_name
    |> String.replace(prefix, "")
    |> Macro.underscore()
    |> String.replace("/", "_")
    |> String.to_atom()
  end
end
