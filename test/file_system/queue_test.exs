defmodule Continuum.FileSystem.QueueTest do
  use ExUnit.Case, async: true
  alias Continuum.FileSystem.Queue

  @root Path.expand("../support/queues", __DIR__)

  test "queues must be configured on init" do
    assert_raise ArgumentError, ~r{\bqueue_name\b}, fn ->
      Queue.init([])
    end
  end

  test "initializing a queue creates directories" do
    name = unique_queue_name()

    Enum.each(~w[queued pulled], fn dir ->
      refute @root
             |> Path.join(name)
             |> Path.join(dir)
             |> File.exists?()
    end)

    Queue.init(root_dir: @root, queue_name: name)

    Enum.each(~w[queued pulled], fn dir ->
      assert @root
             |> Path.join(name)
             |> Path.join(dir)
             |> File.exists?()
    end)
  end

  test "messages can be pushed into the queue" do
    name = unique_queue_name()
    q = Queue.init(root_dir: @root, queue_name: name)

    message = {:message, %{from: "a test"}}
    Queue.push(q, message)

    queued_dir =
      @root
      |> Path.join(name)
      |> Path.join("queued")

    assert [file] = File.ls!(queued_dir)

    assert queued_dir
           |> Path.join(file)
           |> File.read!()
           |> :erlang.binary_to_term()
           |> Kernel.==(message)
  end

  test "messages can be pulled from the queue" do
    name = unique_queue_name()
    q = Queue.init(root_dir: @root, queue_name: name)

    assert Queue.pull(q) == nil

    message = {:message, %{from: "a test"}}
    Queue.push(q, message)

    assert Queue.pull(q).payload == message

    pulled_dir =
      @root
      |> Path.join(name)
      |> Path.join("pulled")

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
    q = Queue.init(root_dir: @root, queue_name: name)
    Queue.push(q, :message)

    message = Queue.pull(q)
    assert File.exists?(message.id)
    Queue.acknowledge(q, message)
    refute File.exists?(message.id)
  end

  test "pulled messages can be failed with a reason flag" do
    name = unique_queue_name()
    q = Queue.init(root_dir: @root, queue_name: name)
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
    q = Queue.init(root_dir: @root, queue_name: name)
    assert Queue.length(q) == 0

    Enum.each(1..10, fn n ->
      Queue.push(q, n)
      assert Queue.length(q) == n
    end)
  end

  defp unique_queue_name do
    name = "q#{System.unique_integer([:positive])}"
    on_exit(name, fn -> File.rm_rf!(Path.join(@root, name)) end)
    name
  end
end
