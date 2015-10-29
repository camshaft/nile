defmodule Nile do
  @doc """
  Expand each item into 0..n items

      iex> Nile.route_into(0..10, &([&1, &1])) |> Enum.to_list()
        [0,0,1,1,2,2,3,3,4,4,5,5..]
  """
  def expand(stream, fun) do
    Stream.resource(
      fn -> {stream, fun} end,
      fn ({stream, fun} = s) ->
        case Nile.Utils.next(stream) do
          {status, _} when status in [:done, :halted] ->
            {:halt, s}
          {:suspended, item, stream} ->
            {fun.(item), {stream, fun}}
        end
      end,
      fn (_) -> :ok end
    )
  end

  @doc """
  Routes items in a stream into a map of lazily created collectables.

  This eagerly evaluates the stream

      iex> Nile.route_into(0..26, &(rem(&1, 3)), fn(_) -> [] end)
        %{0 => [0, 3, 6, 9, 12, 15, 18, 21, 24],
          1 => [1, 4, 7, 10, 13, 16, 19, 22, 25],
          2 => [2, 5, 8, 11, 14, 17, 20, 23, 26]}
  """
  defdelegate route_into(stream, router, factory), to: Nile.Router

  defdelegate pmap(stream, fun), to: Nile.Pmap

  @doc """
  Map over a stream in parallel, spawning a pool of workers.

  Options include:

  * concurrency (defaults to infinity)
  * timeout (defaults to infinity)

  Before using, consider the cost of message passing between processes

      iex> Nile.pmap(0..26, &My.expensive_operation/1) |> Enum.to_list()
        [0,1,2,3,4..]
  """
  defdelegate pmap(stream, fun, opts), to: Nile.Pmap

  @doc """
  Returns the identity of the stream
  """
  def identity(stream) do
    stream |> Stream.map(&(&1))
  end
end
