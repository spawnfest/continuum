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
    Q.push(PotatoProcessor, message)
    Q.push(PearProcessor, message2)
    assert Q.queue_length(PotatoProcessor) == 1
    assert Q.queue_length(PearProcessor) == 1
    Q.push(PotatoProcessor, message)
    assert Q.queue_length(PotatoProcessor) == 2
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
