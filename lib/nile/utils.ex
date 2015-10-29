defmodule Nile.Utils do
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
end
