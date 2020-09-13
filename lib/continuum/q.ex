defmodule Continuum.Q do
  @moduledoc """
  Continuum.Q is the Supervisor for a single named queue.

  It also serves as the primary entrypoint to pushing to a queue through
  `Continuum.Q.Push(ExampleQueue, message)`

  The Q Supervisor will start a number of processes based on the provided named
  queue. If the given queue name is `ExampleQueue` the Q supervisor will start:

    1. a Q.Manager process (Q.ExampleQueue.Manager)
    2. a Task Supervisor (Q.ExampleQueue.Tasks)
    3. a configurable number of worker processes
  """

  use Supervisor

  defdelegate push(queue_name, message), to: Continuum.Q.Manager
  defdelegate queue_length(queue_name), to: Continuum.Q.Manager

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
    backend = Keyword.get(opts, :backend, Continuum.FileSystem.Queue)
    supervisor_name = Module.concat(__MODULE__, queue_name)
    task_supervisor_name = Module.concat(supervisor_name, Tasks)
    group_name = Module.concat(supervisor_name, WorkerGroup)

    backend_config =
      opts
      |> Keyword.take(
        Continuum.FileSystem.Queue.__struct__()
        |> Map.from_struct()
        |> Map.keys()
      )
      |> Keyword.put(:queue_name, backend_queue_name(queue_name))
      |> backend.init()

    :pg2.create(group_name)

    children =
      [
        Supervisor.child_spec(
          {Continuum.Q.Manager,
           [
             name: Module.concat(supervisor_name, Manager),
             backend: backend,
             config: backend_config,
             worker_group: group_name
           ]},
          id: :queue_manager
        ),
        {Task.Supervisor, name: task_supervisor_name}
      ] ++
        worker_specs(
          worker_count,
          backend_config,
          function,
          backend,
          task_supervisor_name,
          group_name
        )

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: supervisor_name
    )
  end

  def init(opts) do
    {:ok, opts}
  end

  def build_with_dead_letters(q_configs, dl_config \\ []) do
    name = Keyword.get(dl_config, :name, DeadLetters)

    root_dir =
      Keyword.get(
        dl_config,
        :root_dir,
        q_configs
        |> hd
        |> Keyword.fetch!(:root_dir)
      )

    dl_config =
      Keyword.merge(
        dl_config,
        root_dir: root_dir,
        name: name
      )

    [
      {__MODULE__, dl_config}
      | Enum.map(q_configs, fn q_config ->
          {
            __MODULE__,
            Keyword.put(
              q_config,
              :dead_letters,
              root_dir: root_dir,
              queue_name: backend_queue_name(name)
            )
          }
        end)
    ]
  end

  defp worker_specs(
         0,
         _queue_name,
         _function,
         _backend,
         _task_supervisor_name,
         _group_name
       ) do
    []
  end

  defp worker_specs(
         count,
         config,
         function,
         backend,
         task_supervisor_name,
         group_name
       ) do
    for idx <- 1..count do
      Supervisor.child_spec(
        {Continuum.Q.Worker,
         [
           function: function,
           config: config,
           backend: backend,
           task_supervisor_name: task_supervisor_name,
           group_name: group_name
         ]},
        id: :"worker_#{idx}"
      )
    end
  end

  defp backend_queue_name(name) do
    name |> Macro.underscore() |> String.replace("/", "-")
  end
end
