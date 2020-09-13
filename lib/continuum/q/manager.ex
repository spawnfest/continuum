defmodule Continuum.Q.Manager do
  @moduledoc """
  Continuum.Q.Manager's purpose is to hold the name of a queue so a caller can
  interact with it later without having to find the server.

  This works through a name generated in the Continuum.Q Supervisor.

  For example, the name of the Manager for ExampleQueue is:
  `Continuum.Q.ExampleQueue.Manager`

  We can then reference the queue easily using the `to_server_name` function
  which predictably generates the named server for a queue.

  In this way a caller only has to know the name of the queue they created.

  A single process also ensures that the queue has only one interface and
  operates as FIFO.  This does have a drawback in that the primary
  bottleneck is pushing a message.
  """

  use GenServer

  @enforce_keys ~w[backend config name worker_group]a
  defstruct backend: nil, config: nil, name: nil, worker_group: nil

  def init(init_arg) do
    manager = struct!(__MODULE__, init_arg)

    {:ok, manager}
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def handle_call({:push, message}, _from, state) do
    state.backend.push(state.config, message)

    state.worker_group
    |> :pg2.get_local_members()
    |> Enum.each(fn member_pid -> GenServer.cast(member_pid, :pull_job) end)

    {:reply, :ok, state}
  end

  def handle_call(:length, _from, state) do
    length = state.backend.length(state.config)

    {:reply, length, state}
  end

  def push(queue_name, message) do
    GenServer.call(queue_name |> to_server_name, {:push, message})
  end

  def queue_length(queue_name) do
    GenServer.call(queue_name |> to_server_name, :length)
  end

  defp to_server_name(queue_name) do
    Continuum.Q |> Module.concat(queue_name) |> Module.concat(Manager)
  end
end
