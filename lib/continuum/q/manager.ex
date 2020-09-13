defmodule Continuum.Q.Manager do
  use GenServer

  def init(init_arg) do
    {:ok, init_arg}
  end

  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    backend = Keyword.fetch!(opts, :backend)
    config = Keyword.fetch!(opts, :config)
    GenServer.start_link(__MODULE__, %{backend: backend, config: config}, name: name)
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
