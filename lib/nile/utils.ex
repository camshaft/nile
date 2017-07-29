defmodule Nile.Utils do
  @doc """
  Fetch the next item in a stream. This will consume a single item at a time.
  """
  def next(nil) do
    {:done, nil}
  end
  def next({:__SUSPENDED__, reducer}) when is_function(reducer) do
    {:cont, []}
    |> reducer.()
    |> wrap_cont()
  end
  def next(reducer) when is_function(reducer) do
    {:cont, []}
    |> reducer.(fn(value, _) -> {:suspend, value} end)
    |> wrap_cont()
  end
  def next(stream) do
    stream
    |> Enumerable.reduce({:cont, []}, fn(value, _) -> {:suspend, value} end)
    |> wrap_cont()
  end

  defp wrap_cont({:suspended, value, stream}) do
    {:suspended, value, {:__SUSPENDED__, stream}}
  end
  defp wrap_cont(other) do
    other
  end

  def halt(nil) do
    :ok
  end
  def halt({:__SUSPENDED__, reducer}) when is_function(reducer) do
    {:halt, nil}
    |> reducer.()
    :ok
  end
  def halt(reducer) when is_function(reducer) do
    {:halt, nil}
    |> reducer.(fn(_, _) -> {:halt, nil} end)
    :ok
  end
  def halt(_) do
    :ok
  end

  @doc """
  Put a value into a collectable. This is a convinience wrapper around `Collectable.into/1`

      iex> collectable = [] |>
          Nile.Utils.put({:cont, 1}) |>
          Nile.Utils.put({:cont, 2}) |>
          Nile.Utils.put({:cont, 3}) |>
          Nile.Utils.put(:done)
        [1,2,3]
  """
  def put({:__COLLECTABLE__, collectable, prev}, :done) do
    collectable.(prev, :done)
  end
  def put({:__COLLECTABLE__, collectable, prev}, value) do
    next = collectable.(prev, value)
    {:__COLLECTABLE__, collectable, next}
  end
  def put(collectable, value) do
    {initial, collectable} = Collectable.into(collectable)
    put({:__COLLECTABLE__, collectable, initial}, value)
  end

  def get_stream({_, stream}), do: stream
  def get_stream({_, _, stream}), do: stream
end
