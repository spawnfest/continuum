defmodule Continuum.DeliveryCounter do
  use Agent

  def start_link([count]) do
    Agent.start_link(fn -> count end, name: __MODULE__)
  end

  def next_count do
    Agent.get_and_update(__MODULE__, fn count -> {count, count + 1} end)
  end
end
