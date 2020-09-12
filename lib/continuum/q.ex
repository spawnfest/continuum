defmodule Continuum.Q do
  use Supervisor
  # supervisor for a pool of processing workers for specific tasks

  # module approach
  #
  # Continuum.Q.enqueue(queue_name, message)
  # underlying module that writes to file system
  # [1], [2], [3]

  # genserver approach
  #
  # Q.enqueue(CoolJobQueue, message)
  # {Continuum.Q, name: CoolJobQueue, workers: 3, function: [m,f], message_validator: }
  #
  #  [GenServer] - responsible for queue init/writes/etc/purge/length
  #       |
  # [1], [2], [3] - responsible for processing these would only rely module

  # reader process?

  def init(opts) do
    {:ok, opts}
  end

  def start_link(opts) do
    queue_name = Keyword.fetch!(opts, :name)
    worker_count = Keyword.get(opts, :workers, 1)
    function = Keyword.fetch!(opts, :function)
    config = %{queue_name: queue_name}
    backend = Keyword.get(opts, :backend, DefaultBackend)

    children =
      [
        Supervisor.child_spec({Continuum.Q.Manager, [name: queue_name, backend: backend]},
          id: :manager
        ),
        {Task.Supervisor, name: SuperVisor}
      ] ++ worker_specs(worker_count, config, function, backend)

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end

  defp worker_specs(0, _queue_name, _function, _backend) do
    []
  end

  defp worker_specs(count, config, function, backend) do
    for idx <- 0..(count - 1) do
      Supervisor.child_spec(
        {Continuum.Q.Worker, [function: function, config: config, backend: backend]},
        id: :"worker_#{idx}"
      )
    end
  end
end

defmodule Continuum.Q.Worker do
  use GenServer

  def init(init_arg) do
    function = Keyword.fetch!(init_arg, :function)
    config = Keyword.fetch!(init_arg, :config)
    backend = Keyword.fetch!(init_arg, :backend)
    timeout = Keyword.get(init_arg, :timeout, 5000)

    {:ok, %{function: function, config: config, backend: backend, timeout: timeout, child_task: nil, message: nil}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_call(:pull_job, _, %{message: nil} = state) do
    if message = state.backend.pull() do
      # we need to rename this
      task = Task.Supervisor.async_nolink(SuperVisor, fn ->
        :timer.kill_after(state.timeout)
        try do
          state.function.(message)
          :ok
        rescue
          _error -> :error
        end
      end)
      {:reply, :ok, %{state | child_task: task, message: message}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call(:pull_job, _, state) do
    {:reply, :ok, state}
  end

  def handle_info({:DOWN, ref, :process, pid, :killed}, %{child_task: %Task{ref: ref, pid: pid}} = state) do
    state.backend.fail(state.message, :timeout)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, %{child_task: nil} = state) do
    {:noreply, state}
  end

  def handle_info({ref, :error}, %{child_task: %Task{ref: ref}} = state) do
    state.backend.fail(state.message, :error)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info({ref, :ok}, %{child_task: %Task{ref: ref}} = state) do
    # state.backend.acknowlege(state.message)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end
end

defmodule Continuum.Q.Manager do
  use GenServer

  def init(init_arg) do
    init_arg.backend.init()
    {:ok, init_arg}
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    backend = Keyword.fetch!(opts, :backend)
    GenServer.start_link(__MODULE__, %{backend: backend}, name: name)
  end

  def handle_call({:push, message}, _from, state) do
    state.backend.push(message)

    {:reply, :ok, state}
  end

  def handle_call(:length, _from, state) do
    length = state.backend.length()

    {:reply, length, state}
  end

  def push(queue_name, message) do
    GenServer.call(queue_name, {:push, message})
  end

  def queue_length(queue_name) do
    GenServer.call(queue_name, :length)
  end
end