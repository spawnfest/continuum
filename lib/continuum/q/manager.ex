defmodule Continuum.Q.Manager do
  use GenServer

  @enforce_keys ~w[backend config name]a
  defstruct backend: nil, config: nil, name: nil

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
