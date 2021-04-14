defmodule Spear.Records do
  @moduledoc false

  defmacro defrecords(prefix, path) do
    quote do
      require Record

      records =
        Record.extract_all(from: unquote(path))
        |> Enum.map(fn {name, attrs} -> {name, Atom.to_string(name), attrs} end)
        |> Enum.filter(fn {_name, string_name, _attrs} ->
          String.starts_with?(string_name, unquote(prefix))
        end)
        |> Enum.map(&unquote(__MODULE__).to_short_name(&1, unquote(prefix)))

      for {name, short_name, attrs} <- records do
        Record.defrecord(short_name, name, attrs)
      end
    end
  end

  def to_short_name({name, string_name, attrs}, prefix) do
    short_name =
      string_name
      |> String.replace(prefix, "")
      |> Macro.underscore()
      |> String.replace("/", "_")
      |> String.to_atom()

    {name, short_name, attrs}
  end
end
