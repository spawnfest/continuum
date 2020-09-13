# struct queue_name: string

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
    Agent.get_and_update(:"#{config.queue_name}", fn [first | rest] -> {first, rest} end)
  end

  def length(config) do
    Agent.get(:"#{config.queue_name}", & &1) |> Kernel.length
  end

  def fail(_config, message, _reason) do
    send(message.pid, :failed)
  end
end

defmodule Continuum.QTest do
  use ExUnit.Case, async: true
  alias Continuum.Q

  test "push an item into different queues" do
    start_supervised!(
      {Q,
       [
         name: PotatoProcessor,
         workers: 0,
         function: &Example.send_message/1,
         backend: TestBackend
       ]}
    )

    start_supervised!(
      {Q,
       [
         name: PearProcessor,
         workers: 0,
         function: &Example.send_message/1,
         backend: TestBackend
       ]}
    )

    message = "tater_tot"
    message2 = "tater_tot2"
    Q.Manager.push(PotatoProcessor, message)
    Q.Manager.push(PearProcessor, message2)
    assert Q.Manager.queue_length(PotatoProcessor) == 1
    assert Q.Manager.queue_length(PearProcessor) == 1
    Q.Manager.push(PotatoProcessor, message)
    assert Q.Manager.queue_length(PotatoProcessor) == 2
  end

  test "has worker pool" do
    worker_count = 3

    queue =
      start_supervised!(
        {Q,
         [
           name: TomatoProcessor,
           workers: worker_count,
           function: &Example.send_message/1,
           backend: TestBackend
         ]}
      )

    assert Supervisor.count_children(queue).workers == worker_count + 1
  end
end

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
