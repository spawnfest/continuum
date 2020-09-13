defmodule Example.StressTester do
  use GenServer

  @enforce_keys ~w[queues]a
  defstruct queues: []

  def init(init_arg) do
    tester = struct!(__MODULE__, init_arg)

    Process.send_after(self(), :flood, 1000)

    {:ok, tester}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_info(:flood, state) do
  Process.send_after(self(), :flood, 1000)

  {:noreply, state}
end
end
