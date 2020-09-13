defmodule Continuum.Q.Worker do
  use GenServer

  @enforce_keys ~w[function config backend task_supervisor_name group_name]a
  defstruct function: nil,
            config: nil,
            backend: nil,
            child_task: nil,
            message: nil,
            task_supervisor_name: nil,
            group_name: nil,
            timeout: 5000

  def init(init_arg) do
    worker = struct!(__MODULE__, init_arg)
    :ok = :pg2.join(worker.group_name, self())

    {:ok, worker}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_cast(:pull_job, %{message: nil} = state) do
    if message = state.backend.pull(state.config) do
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

      {:noreply, %{state | child_task: task, message: message}}
    else
      {:noreply, state}
    end
  end

  def handle_cast(:pull_job, state) do
    {:noreply, state}
  end

  # This handles the case where do a job reaches the timeout set in the Task
  def handle_info(
        {:DOWN, ref, :process, pid, :killed},
        %{child_task: %Task{ref: ref, pid: pid}} = state
      ) do
    state.backend.fail(state.config, state.message, :timeout)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  # When a task exits successfully it will still callback with a down message
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, %{child_task: nil} = state) do
    {:noreply, state}
  end

  # All errors reported back from the Task Supervisor should be counted as
  # failures
  def handle_info({ref, :error}, %{child_task: %Task{ref: ref}} = state) do
    state.backend.fail(state.config, state.message, :error)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info({ref, :ok}, %{child_task: %Task{ref: ref}} = state) do
    state.backend.acknowlege(state.config, state.message)

    {:noreply, %{state | child_task: nil, message: nil}}
  end

  def handle_info(msg, state) do
    IO.inspect(msg)
    {:noreply, state}
  end
end
