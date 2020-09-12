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
  def init do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def push(item) do
    Agent.update(__MODULE__, fn queue -> queue ++ [item] end)
  end

  def pull() do
    Agent.get_and_update(__MODULE__, fn [first | rest] -> {first, rest} end)
  end

  def length() do
    Agent.get(__MODULE__, & &1) |> length
  end

  def fail(message, _reason) do
    send(message.pid, :failed)
  end
end

defmodule Continuum.QTest do
  use ExUnit.Case, async: true
  alias Continuum.Q

  test "push an item into queue" do
    start_supervised!(
      {Q,
       [
         name: PotatoProcessor,
         workers: 0,
         function: &Example.send_message/1,
         backend: TestBackend
       ]}
    )

    message = "tater_tot"
    Q.Manager.push(PotatoProcessor, message)
    assert Q.Manager.queue_length(PotatoProcessor) == 1
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
    TestBackend.init()
    TestBackend.push(%{pid: self()})
    Task.Supervisor.start_link(name: SuperVisor)

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.send_message/1,
           config: %{queue_name: ExampleQueue},
           backend: TestBackend
         ]}
      )

    GenServer.call(worker, :pull_job)

    assert_receive :response
  end

  test "can fail a job" do
    TestBackend.init()
    TestBackend.push(%{pid: self()})
    Task.Supervisor.start_link(name: SuperVisor)
    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.raise_error/1,
           config: %{queue_name: ExampleQueue},
           backend: TestBackend
         ]}
      )

    GenServer.call(worker, :pull_job)

    assert_receive :failed
  end

  test "can timeout a job" do
    TestBackend.init()
    TestBackend.push(%{pid: self()})
    Task.Supervisor.start_link(name: SuperVisor)

    worker =
      start_supervised!(
        {Q.Worker,
         [
           function: &Example.take_too_long/1,
           config: %{queue_name: ExampleQueue},
           timeout: 100,
           backend: TestBackend
         ]}
      )

    GenServer.call(worker, :pull_job)

    assert_receive :failed, 30_000
  end
end
