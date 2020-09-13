defmodule Continuum.FileSystem.Directory do
  def setup_named(dirs, paths) do
    dir = Path.join(paths)
    File.mkdir_p!(dir)
    Map.put(dirs, paths |> List.last() |> String.to_atom(), dir)
  end

  def move_file(from_path, to_dir, new_suffix \\ "") do
    new_path = Path.join(to_dir, Path.basename(from_path) <> new_suffix)

    case File.rename(from_path, new_path) do
      :ok -> {:ok, new_path}
      error -> error
    end
  end

  def first_file(dir) do
    case dir |> File.ls!() |> Enum.sort() do
      [first | _rest] ->
        {:ok, Path.join(dir, first)}

      [] ->
        :error
    end
  end

  def all_files(dir) do
    dir
    |> File.ls!()
    |> Enum.sort()
    |> Enum.map(fn file -> Path.join(dir, file) end)
  end

  def file_count(dir) do
    dir |> File.ls!() |> length()
  end
end
