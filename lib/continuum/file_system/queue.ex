defmodule Continuum.FileSystem.Queue do
  import Kernel, except: [length: 1]
  alias Continuum.DeliveryCounter
  alias Continuum.FileSystem.Message

  @enforce_keys ~w[root_dir queue_name]a
  defstruct root_dir: nil, queue_name: nil

  def init(config) do
    q = struct!(__MODULE__, config)

    Enum.each(~w[queued pulled], fn dir_name ->
      q |> queue_dir(dir_name) |> File.mkdir_p!()
    end)

    q
  end

  def push(q, message) do
    serialized = :erlang.term_to_binary(message)
    tmp = System.tmp_dir!()
    file_name = generate_file_name()
    tmp_file = Path.join(tmp, file_name)
    queued_file = Path.join([q.root_dir, q.queue_name, "queued", file_name])
    File.write!(tmp_file, serialized)
    File.rename!(tmp_file, queued_file)
  end

  def pull(q) do
    with [first | _rest] <- q |> queue_dir("queued") |> File.ls!(),
         pulled_file <- queue_file(q, "pulled", first),
         :ok <- File.rename(queue_file(q, "queued", first), pulled_file),
         {:ok, serialized} <- File.read(pulled_file) do
      Message.new(
        id: pulled_file,
        payload: :erlang.binary_to_term(serialized)
      )
    else
      _error ->
        nil
    end
  end

  def acknowledge(_q, message) do
    File.rm!(message.id)
  end

  def fail(q, message, flag \\ :failed)
      when flag in ~w[failed error timeout]a do
    new_attempts = message.attempts ++ [flag]

    new_flags =
      new_attempts
      |> Enum.map(fn f ->
        f |> to_string |> String.first() |> String.upcase()
      end)
      |> Enum.join()

    new_file_name =
      message.id
      |> Path.basename()
      |> String.replace(~r{:[FET]+\z}, "")
      |> Kernel.<>(":#{new_flags}")

    File.rename!(message.id, queue_file(q, "queued", new_file_name))
  end

  def length(q) do
    q |> queue_dir("queued") |> File.ls!() |> Kernel.length()
  end

  defp generate_file_name do
    time = System.system_time(:millisecond)
    deliveries = DeliveryCounter.next_count()
    os_pid = System.pid()

    pid =
      self()
      |> :erlang.pid_to_list()
      |> to_string

    random_bytes =
      :crypto.strong_rand_bytes(10)
      |> Base.encode16()

    {:ok, hostname} = :inet.gethostname()

    safe_hostname =
      hostname
      |> to_string()
      |> String.replace(~r{[/:]}, fn
        "/" -> "\\057"
        ":" -> "\\072"
      end)

    Enum.join(
      [time, deliveries, os_pid, pid, random_bytes, safe_hostname],
      "."
    )
  end

  defp queue_dir(q, dir_name) do
    Path.join([q.root_dir, q.queue_name, dir_name])
  end

  defp queue_file(q, dir_name, file_name) do
    Path.join([q.root_dir, q.queue_name, dir_name, file_name])
  end
end
