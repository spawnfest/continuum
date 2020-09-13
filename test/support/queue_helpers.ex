defmodule Continuum.QueueHelpers do
  @root Path.expand("../support/queues", __DIR__)

  def root_dir do
    @root
  end

  def from_root(paths) do
    Path.join([@root | List.wrap(paths)])
  end

  def unique_queue_name do
    name = "q#{System.unique_integer([:positive])}"
    ExUnit.Callbacks.on_exit(name, fn ->
      File.rm_rf!(Path.join(@root, name))
    end)
    name
  end
end
