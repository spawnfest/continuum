defmodule Continuum.Q do
  use Supervisor

  def init(opts) do
    {:ok, opts}
  end

  def child_spec(args) do
    queue = Keyword.fetch!(args, :name)
    id = Module.concat(__MODULE__, queue)

    %{
      id: id,
      start: {__MODULE__, :start_link, [args]}
    }
  end

  def start_link(opts) do
    queue_name = Keyword.fetch!(opts, :name)
    worker_count = Keyword.get(opts, :workers, 1)
    function = Keyword.fetch!(opts, :function)
    backend = Keyword.get(opts, :backend, DefaultBackend)
    supervisor_name = Module.concat(__MODULE__, queue_name)
    task_supervisor_name = Module.concat(supervisor_name, Tasks)

    string_queue_name =
      queue_name
      |> to_string
      |> String.replace("Elixir.", "")
      |> String.replace(".", "_")
      |> String.downcase()

    backend_config = backend.init(queue_name: string_queue_name, root_dir: "")

    children =
      [
        Supervisor.child_spec(
          {Continuum.Q.Manager,
           [name: Module.concat(supervisor_name, Manager), backend: backend, config: backend_config]},
          id: :queue_manager
        ),
        {Task.Supervisor, name: task_supervisor_name}
      ] ++ worker_specs(worker_count, backend_config, function, backend, task_supervisor_name)

    Supervisor.start_link(children, strategy: :one_for_one, name: supervisor_name)
  end

  defp worker_specs(0, _queue_name, _function, _backend, _task_supervisor_name) do
    []
  end

  defp worker_specs(count, config, function, backend, task_supervisor_name) do
    for idx <- 1..count do
      Supervisor.child_spec(
        {Continuum.Q.Worker,
         [
           function: function,
           config: config,
           backend: backend,
           task_supervisor_name: task_supervisor_name
         ]},
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
    task_supervisor_name = Keyword.fetch!(init_arg, :task_supervisor_name)
    timeout = Keyword.get(init_arg, :timeout, 5000)

    {:ok,
     %{
       function: function,
       config: config,
       backend: backend,
       timeout: timeout,
       child_task: nil,
       message: nil,
       task_supervisor_name: task_supervisor_name
     }}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_call(:pull_job, _, %{message: nil} = state) do
    if message = state.backend.pull(state.config) do
      # we need to rename this
      task =
        Task.Supervisor.async_nolink(state.task_supervisor_name, fn ->
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

  def handle_info(
        {:DOWN, ref, :process, pid, :killed},
        %{child_task: %Task{ref: ref, pid: pid}} = state
      ) do
    state.backend.fail(state.config, state.message, :timeout)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info({:DOWN, _ref, :process, _pid, :normal}, %{child_task: nil} = state) do
    {:noreply, state}
  end

  def handle_info({ref, :error}, %{child_task: %Task{ref: ref}} = state) do
    state.backend.fail(state.config, state.message, :error)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info({ref, :ok}, %{child_task: %Task{ref: ref}} = state) do
    # state.backend.acknowlege(state.config, state.message)

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
    {:ok, init_arg}
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    backend = Keyword.fetch!(opts, :backend)
    config = Keyword.fetch!(opts, :config)
    GenServer.start_link(__MODULE__, %{backend: backend, config: config}, name: name)
  end

  def handle_call({:push, message}, _from, state) do
    state.backend.push(state.config, message)

    {:reply, :ok, state}
  end

  def handle_call(:length, _from, state) do
    length = state.backend.length(state.config)

    {:reply, length, state}
  end

  def push(queue_name, message) do
    GenServer.call(queue_name |> to_server_name, {:push, message})
  end

  def queue_length(queue_name) do
    GenServer.call(queue_name |> to_server_name, :length)
  end

  defp to_server_name(queue_name) do
    Continuum.Q |> Module.concat(queue_name) |> Module.concat(Manager)
  end
end
