defmodule Continuum.FileSystem.Message do
  @enforce_keys ~w[id payload]a
  defstruct id: nil, payload: nil, attempts: []

  def new(fields) do
    message = struct!(__MODULE__, fields)
    %__MODULE__{message | attempts: parse_flags(message.id)}
  end

  defp parse_flags(file_name) do
    case Regex.run(~r{:([FET]+)\z}, file_name) do
      [_match, flags] ->
        flags
        |> String.graphemes
        |> Enum.map(fn
          "F" -> :failed
          "E" -> :error
          "T" -> :timeout
        end)

      nil ->
        []
    end
  end
end
