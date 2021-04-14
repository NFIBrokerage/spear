defmodule Spear.Records do
  @moduledoc false

  @doc """
  a macro that extracts all records from the gpb generated .hrl files in src/
  for a particular prefix

  e.g. "event_store.client.streams."

  it turns them into little macros with Record.defrecord/2
  so they are easier to use/match-with in other files in Spear

  if you see other stuff in spear like

      iex> import Spear.Records.Streams
      iex> match?(read_resp(content: {:checkpoint, _}), {:"event_store.client.streams.ReadResp", content: {:checkpoint, ..}})
      true

  this is where that comes from!
  """
  defmacro def_all_records(prefix, path) do
    quote do
      require Record

      records =
        Record.extract_all(from: unquote(path))
        |> Enum.map(fn {name, attrs} -> {name, Atom.to_string(name), attrs} end)
        |> Enum.filter(fn {_name, string_name, _attrs} ->
          String.starts_with?(string_name, unquote(prefix))
        end)
        |> Enum.map(&unquote(__MODULE__).with_short_name(&1, unquote(prefix)))

      for {name, short_name, attrs} <- records do
        Record.defrecord(short_name, name, attrs)
      end
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
