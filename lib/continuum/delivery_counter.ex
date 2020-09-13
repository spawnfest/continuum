defmodule Continuum.DeliveryCounter do
  use Agent

  def start_link([count]) do
    Agent.start_link(fn -> count end, name: __MODULE__)
  end

  def next_count do
    Agent.get_and_update(__MODULE__, fn count ->
      {
        count
        |> to_string()
        |> String.pad_leading(7, "0"),
        (if count < 9_999_999, do: count + 1, else: 0)
      }
    end)
  end
end
