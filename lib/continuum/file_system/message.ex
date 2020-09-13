defmodule Continuum.FileSystem.Message do
  @enforce_keys ~w[path payload]a
  defstruct path: nil, id: nil, payload: nil, attempts: []

  def new(fields) do
    path = Keyword.fetch!(fields, :path)

    {id, attempts} =
      case String.split(path, ":", parts: 2) do
        [id] ->
          {id, []}

        [id, flags] ->
          {id, parse_flags(flags)}
      end

    struct!(__MODULE__, Keyword.merge(fields, id: id, attempts: attempts))
  end

  def flag_to_suffix(message, nil) do
    flag_to_suffix(message, :failed)
  end

  def flag_to_suffix(message, flag)
  when flag in ~w[failed error timeout dead]a do
    new_flag = flag |> to_string |> String.first() |> String.upcase()

    if message.attempts == [] do
      ":#{new_flag}"
    else
      new_flag
    end
  end

  defp parse_flags(flags) do
    flags
    |> String.graphemes()
    |> Enum.map(fn
      "F" -> :failed
      "E" -> :error
      "T" -> :timeout
      "D" -> :dead
    end)
  end
end
