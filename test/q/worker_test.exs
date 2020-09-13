defmodule Continuum.Q.WorkerTest do
  use ExUnit.Case, async: true
  alias Continuum.Q

  setup do
    task_supervisor = TaskSupervisor
    worker_group = WorkerGroup
    config = TestBackend.init([queue_name: "example_queue", root_dir: ""])

    Task.Supervisor.start_link(name: TaskSupervisor)
    :pg2.create(worker_group)

    {:ok, worker_group: worker_group, task_supervisor: task_supervisor, config: config}
  end

  test "can process a job", %{task_supervisor: task_supervisor, worker_group: worker_group, config: config} do
    TestBackend.push(config, %{pid: self()})

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.send_message/1,
           config: Map.new(config),
           backend: TestBackend,
           task_supervisor_name: task_supervisor,
           group_name: worker_group
         ]}
      )

    GenServer.cast(worker, :pull_job)

    assert_receive :response
  end

  test "can fail a job", %{task_supervisor: task_supervisor, worker_group: worker_group, config: config} do
    TestBackend.push(config, %{pid: self()})

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.raise_error/1,
           config: Map.new(config),
           backend: TestBackend,
           task_supervisor_name: task_supervisor,
           group_name: worker_group
         ]}
      )

    GenServer.cast(worker, :pull_job)

    assert_receive :failed
  end

  test "can timeout a job", %{task_supervisor: task_supervisor, worker_group: worker_group, config: config} do
    TestBackend.push(config, %{pid: self()})

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.take_too_long/1,
           config: Map.new(config),
           timeout: 100,
           backend: TestBackend,
           task_supervisor_name: task_supervisor,
           group_name: worker_group
         ]}
      )

    GenServer.cast(worker, :pull_job)

    assert_receive :failed, 30_000
  end
end
