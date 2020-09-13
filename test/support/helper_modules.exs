defmodule Example do
  def send_message(message) do
    send(message.pid, :response)
  end

  def take_too_long(message) do
    :timer.sleep(30_000)
    send(message.pid, :response)
  end

  def raise_error(_message) do
    raise "ERROR"
  end
end

defmodule TestBackend do
  import Kernel, except: [length: 1]

  def init(config) do
    queue_name = Keyword.fetch!(config, :queue_name)
    root_dir = Keyword.fetch!(config, :root_dir)

    Agent.start_link(fn -> [] end, name: :"#{queue_name}")

    %{queue_name: queue_name, root_dir: root_dir}
  end

  def push(config, item) do
    Agent.update(:"#{config.queue_name}", fn queue -> queue ++ [item] end)
  end

  def pull(config) do
    Agent.get_and_update(:"#{config.queue_name}", fn
      [first | rest] -> {first, rest}
      [] -> {nil, []}
    end)
  end

  def length(config) do
    Agent.get(:"#{config.queue_name}", & &1) |> Kernel.length()
  end

  def acknowledge(_config, _message) do
    # this should be smarter
  end

  def fail(_config, message, _reason) do
    send(message.pid, :failed)
  end
end
