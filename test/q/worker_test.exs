defmodule Continuum.Q.WorkerTest do
  use ExUnit.Case, async: true
  alias Continuum.Q

  test "can process a job" do
    config = [queue_name: "example_queue", root_dir: ""]
    Task.Supervisor.start_link(name: TaskSupervisor)

    config
    |> TestBackend.init()
    |> TestBackend.push(%{pid: self()})

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.send_message/1,
           config: Map.new(config),
           backend: TestBackend,
           task_supervisor_name: TaskSupervisor
         ]}
      )

    GenServer.call(worker, :pull_job)

    assert_receive :response
  end

  test "can fail a job" do
    config = [queue_name: "example_queue", root_dir: ""]

    Task.Supervisor.start_link(name: TaskSupervisor)

    config
    |> TestBackend.init()
    |> TestBackend.push(%{pid: self()})

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.raise_error/1,
           config: Map.new(config),
           backend: TestBackend,
           task_supervisor_name: TaskSupervisor
         ]}
      )

    GenServer.call(worker, :pull_job)

    assert_receive :failed
  end

  test "can timeout a job" do
    config = [queue_name: "example_queue", root_dir: ""]

    Task.Supervisor.start_link(name: TaskSupervisor)

    config
    |> TestBackend.init()
    |> TestBackend.push(%{pid: self()})

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.take_too_long/1,
           config: Map.new(config),
           timeout: 100,
           backend: TestBackend,
           task_supervisor_name: TaskSupervisor
         ]}
      )

    GenServer.call(worker, :pull_job)

    assert_receive :failed, 30_000
  end
end
