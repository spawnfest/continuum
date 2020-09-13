defmodule Continuum.FileSystem.Queue do
  import Kernel, except: [length: 1]
  alias Continuum.FileSystem.{Directory, File, Message}

  @enforce_keys ~w[root_dir queue_name]a
  defstruct root_dir: nil,
            queue_name: nil,
            dirs: Map.new(),
            max_retries: :infinity,
            dead_letters: nil,
            max_message_bytes: 1_024 * 1_024,
            max_queued_messages: 1_000,
            message_ttl_seconds: 60 * 60

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
    count = Directory.file_count(q.dirs.queued)

    :telemetry.execute(
      [:queue, :length],
      %{length: count},
      %{queue_name: q.queue_name}
    )

    if count < q.max_queued_messages do
      case File.serialize_to_tmp_file(message, q.max_message_bytes) do
        {:ok, tmp_file} ->
          Directory.move_file(tmp_file, q.dirs.queued)

          :telemetry.execute(
            [:queue, :push],
            %{items: 1},
            %{queue_name: q.queue_name}
          )

          :ok

        error ->
          error
      end
    else
      {:error, "queue full"}
    end
  end

  def pull(q) do
    with {:ok, first} <- Directory.first_file(q.dirs.queued),
         pulled_file <- Directory.move_file(first, q.dirs.pulled),
         {:ok, deserialized} <- File.deserialize_from(pulled_file) do
      message = Message.new(path: pulled_file, payload: deserialized)

      if System.system_time(:millisecond) - message.timestamp >
           q.message_ttl_seconds * 1_000 do
        fail(q, message, :dead)
        pull(q)
      else
        :telemetry.execute(
          [:queue, :pull],
          %{timestamp: message.timestamp},
          %{queue_name: q.queue_name}
        )

        message
      end
    else
      _error ->
        nil
    end
  end

  def acknowledge(_q, message) do
    File.delete(message.path)
  end

  def fail(queue, message, flag \\ nil)

  def fail(%__MODULE__{dead_letters: dead_letters} = q, message, :dead)
      when not is_nil(dead_letters) do
    new_suffix = Message.flag_to_suffix(message, :dead)
    Directory.move_file(message.path, q.dead_letters.dirs.queued, new_suffix)
  end

  def fail(_q, message, :dead) do
    File.delete(message.path)
  end

  def fail(
        %__MODULE__{max_retries: max_retries} = q,
        %Message{attempts: attempts} = message,
        _flag
      )
      when Kernel.length(attempts) >= max_retries do
    if q.dead_letters do
      fail(q, message, :dead)
    else
      File.delete(message.path)
    end
  end

  def fail(q, message, flag) do
    new_suffix = Message.flag_to_suffix(message, flag)
    Directory.move_file(message.path, q.dirs.queued, new_suffix)
  end

  def length(q) do
    Directory.file_count(q.dirs.queued)
  end
end
