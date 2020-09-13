defmodule Continuum.FileSystem.Directory do
  def setup_named(dirs, paths) do
    dir = Path.join(paths)
    File.mkdir_p!(dir)
    Map.put(dirs, paths |> List.last() |> String.to_atom(), dir)
  end

  def move_file(from_path, to_dir, new_suffix \\ "") do
    new_path = Path.join(to_dir, Path.basename(from_path) <> new_suffix)
    File.rename!(from_path, new_path)
    new_path
  end

  def first_file(dir) do
    case dir |> File.ls!() |> Enum.sort() do
      [first | _rest] ->
        {:ok, Path.join(dir, first)}

      [] ->
        :error
    end
  end

  def file_count(dir) do
    dir |> File.ls!() |> length()
  end
end
