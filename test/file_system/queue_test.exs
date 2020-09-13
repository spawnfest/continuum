defmodule Continuum.FileSystem.QueueTest do
  use ExUnit.Case, async: true
  import Continuum.QueueHelpers
  alias Continuum.FileSystem.Queue

  test "queues must be configured on init" do
    assert_raise ArgumentError, ~r{\bqueue_name\b}, fn ->
      Queue.init([])
    end
  end

  test "initializing a queue creates directories" do
    name = unique_queue_name()

    Enum.each(~w[queued pulled], fn dir ->
      refute from_root([name, dir])
             |> File.exists?()
    end)

    Queue.init(root_dir: root_dir(), queue_name: name)

    Enum.each(~w[queued pulled], fn dir ->
      assert from_root([name, dir])
             |> File.exists?()
    end)
  end

  test "messages can be pushed into the queue" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)

    message = {:message, %{from: "a test"}}
    Queue.push(q, message)

    queued_dir = from_root([name, "queued"])
    assert [file] = File.ls!(queued_dir)

    assert queued_dir
           |> Path.join(file)
           |> File.read!()
           |> :erlang.binary_to_term()
           |> Kernel.==(message)
  end

  test "messages can be pulled from the queue" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)

    assert Queue.pull(q) == nil

    message = {:message, %{from: "a test"}}
    Queue.push(q, message)

    assert Queue.pull(q).payload == message

    pulled_dir = from_root([name, "pulled"])
    assert [file] = File.ls!(pulled_dir)

    assert pulled_dir
           |> Path.join(file)
           |> File.read!()
           |> :erlang.binary_to_term()
           |> Kernel.==(message)

    assert Queue.pull(q) == nil
  end

  test "pulled messages can be acknowledged" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)
    Queue.push(q, :message)

    message = Queue.pull(q)
    assert File.exists?(message.path)
    Queue.acknowledge(q, message)
    refute File.exists?(message.path)
  end

  test "pulled messages can be failed with a reason flag" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)
    Queue.push(q, :message)

    assert pulled = Queue.pull(q)
    assert pulled.attempts == []
    Queue.fail(q, pulled, :timeout)
    assert timeout = Queue.pull(q)
    assert timeout.attempts == [:timeout]
    Queue.fail(q, timeout, :error)
    assert error = Queue.pull(q)
    assert error.attempts == [:timeout, :error]
    Queue.fail(q, error)
    assert failed = Queue.pull(q)
    assert failed.attempts == [:timeout, :error, :failed]
  end

  test "the length of the queue can be queried" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)
    assert Queue.length(q) == 0

    Enum.each(1..10, fn n ->
      Queue.push(q, n)
      assert Queue.length(q) == n
    end)
  end
end
