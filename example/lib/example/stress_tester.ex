defmodule Example.StressTester do
  use GenServer

  alias Continuum.Q

  @enforce_keys ~w[queues]a
  defstruct queues: [], multiplier: 1

  def init(init_arg) do
    tester = struct!(__MODULE__, init_arg)

    {:ok, tester, {:continue, :queue_messages}}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def handle_continue(:queue_messages, state) do
    :timer.sleep(1000)

    :telemetry.execute(
      [:queue, :tester],
      %{per_second: 500}
    )

    state.queues
    |> Enum.each(fn q ->
      Enum.each(0..(500), fn _x -> Task.async(fn -> Q.push(q, "a messages") end) end)
    end)

    {:noreply, %__MODULE__{state | multiplier: state.multiplier + 1}, {:continue, :queue_messages}}
  end

end
