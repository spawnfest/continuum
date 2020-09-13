defmodule Continuum.FileSystem.Queue do
  import Kernel, except: [length: 1]
  alias Continuum.FileSystem.{Directory, File, Message}

  @enforce_keys ~w[root_dir queue_name]a
  defstruct root_dir: nil, queue_name: nil, dirs: Map.new()

  def init(config) do
    q = struct!(__MODULE__, config)

    %__MODULE__{
      q
      | dirs:
          q.dirs
          |> Directory.setup_named([q.root_dir, q.queue_name, "queued"])
          |> Directory.setup_named([q.root_dir, q.queue_name, "pulled"])
    }
  end

  def push(q, message) do
    tmp_file = File.serialize_to_tmp_file(message)
    Directory.move_file(tmp_file, q.dirs.queued)
  end

  def pull(q) do
    with {:ok, first} <- Directory.first_file(q.dirs.queued),
         pulled_file <- Directory.move_file(first, q.dirs.pulled),
         {:ok, deserialized} <- File.deserialize_from(pulled_file) do
      Message.new(path: pulled_file, payload: deserialized)
    else
      _error ->
        nil
    end
  end

  def acknowledge(_q, message) do
    File.delete(message.path)
  end

  def fail(q, message, flag \\ nil) do
    new_suffix = Message.flag_to_suffix(message, flag)
    Directory.move_file(message.path, q.dirs.queued, new_suffix)
  end

  def length(q) do
    Directory.file_count(q.dirs.queued)
  end
end
