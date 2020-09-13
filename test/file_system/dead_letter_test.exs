defmodule Continuum.FileSystem.DeadLetterTest do
  use ExUnit.Case, async: true
  import Continuum.QueueHelpers
  alias Continuum.FileSystem.Queue

  test "max retries is configurable" do
    q =
      Queue.init(
        root_dir: root_dir(),
        queue_name: unique_queue_name(),
        max_retries: 3
      )

    Queue.push(q, :message)

    # first attempt
    assert message = Queue.pull(q)
    Queue.fail(q, message)

    # retries
    assert message = Queue.pull(q)
    Queue.fail(q, message)
    assert message = Queue.pull(q)
    Queue.fail(q, message)
    assert message = Queue.pull(q)
    Queue.fail(q, message)

    assert Queue.pull(q) == nil
  end

  test "dead messages can be sent to another queue" do
    dead_letters =
      Queue.init(
        root_dir: root_dir(),
        queue_name: unique_queue_name(),
        max_retries: 0
      )

    q =
      Queue.init(
        root_dir: root_dir(),
        queue_name: unique_queue_name(),
        max_retries: 3,
        dead_letters: dead_letters
      )

    Queue.push(q, :message)

    # first attempt
    assert message = Queue.pull(q)
    Queue.fail(q, message)

    # retries
    assert message = Queue.pull(q)
    Queue.fail(q, message)
    assert message = Queue.pull(q)
    Queue.fail(q, message)
    assert message = Queue.pull(q)
    Queue.fail(q, message)
    assert Queue.pull(q) == nil

    assert message = Queue.pull(dead_letters)
    assert message.attempts == [:failed, :failed, :failed, :dead]
  end

  test "dead letters can be set with the config of another queue" do
    dead_letters = [
      root_dir: root_dir(),
      queue_name: unique_queue_name(),
      max_retries: 0
    ]

    q =
      Queue.init(
        root_dir: root_dir(),
        queue_name: unique_queue_name(),
        max_retries: 0,
        dead_letters: dead_letters
      )

    Queue.push(q, :message)
    assert message = Queue.pull(q)
    Queue.fail(q, message)

    assert message = Queue.pull(q.dead_letters)
    assert message.attempts == [:dead]
  end

  test "messages can be manually killed" do
    dead_letters =
      Queue.init(
        root_dir: root_dir(),
        queue_name: unique_queue_name(),
        max_retries: 0
      )

    q =
      Queue.init(
        root_dir: root_dir(),
        queue_name: unique_queue_name(),
        max_retries: 3,
        dead_letters: dead_letters
      )

    Queue.push(q, :message)

    # first attempt
    assert message = Queue.pull(q)
    Queue.fail(q, message, :dead)

    assert Queue.pull(q) == nil

    assert message = Queue.pull(dead_letters)
    assert message.attempts == [:dead]
  end
end
