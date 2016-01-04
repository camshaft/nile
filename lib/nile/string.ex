defmodule Nile.String do
  @doc """
  Split a string stream on a delimeter

      iex> Nile.split(stream) |> Enum.to_list()
        ["line 1", "line 2", "line 3"]
  """
  def split(stream, delimeter \\ "\n") do
    Stream.resource(
      fn -> {stream, []} end,
      fn
        ({:empty, stream}) ->
          {:halt, stream}
        ({stream, acc}) ->
          case Nile.Utils.next(stream) do
            {status, stream} when status in [:done, :halted] ->
              {[], {:empty, stream}}
            {:suspended, item, stream} ->
              {lines, acc} = [acc, item] |> try_split(delimeter)
              {lines, {stream, acc}}
          end
      end,
      fn (_) -> :ok end
    )
  end

  defp try_split(chunk, delimeter) do
    chunks = chunk
    |> :erlang.iolist_to_binary()
    |> String.split(delimeter)

    case chunks do
      [acc] ->
        {[], acc}
      lines ->
        case Enum.split(lines, -1) do
          {chunks, [""]} ->
            {chunks, []}
          {chunks, [acc]} ->
            {chunks, acc}
        end
    end
  end
end
