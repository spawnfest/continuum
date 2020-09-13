defmodule Continuum.Q do
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
      |> Keyword.put(:queue_name, Macro.underscore(queue_name))
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
end
