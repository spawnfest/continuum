defmodule Continuum.FileSystem.File do
  alias Continuum.DeliveryCounter

  def serialize_to_tmp_file(term, byte_limit) do
    serialized = :erlang.term_to_binary(term)

    if byte_size(serialized) <= byte_limit do
      tmp_file = Path.join(System.tmp_dir!(), generate_file_name())
      File.write!(tmp_file, serialized)
      {:ok, tmp_file}
    else
      {:error, "message too large"}
    end
  end

  def deserialize_from(path) do
    with {:ok, serialized} <- File.read(path) do
      {:ok, :erlang.binary_to_term(serialized)}
    end
  end

  def delete(path) do
    File.rm!(path)
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
      |> String.replace(["/", ":"], fn
        "/" -> "\\057"
        ":" -> "\\072"
      end)

    Enum.join(
      [time, deliveries, os_pid, pid, random_bytes, safe_hostname],
      "."
    )
  end
end
