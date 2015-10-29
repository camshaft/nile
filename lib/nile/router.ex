defmodule Nile.Router do
  def route_into(stream, router, factory) do
    consume(stream, router, factory, %{})
  end

  defp consume(stream, router, factory, collectables) do
    case Nile.Utils.next(stream) do
      {status, _} when status in [:done, :halted] ->
        collectables
        |> Enum.reduce(%{}, fn({name, collectable}, acc) ->
          collectable = Nile.Utils.put(collectable, :done)
          Map.put(acc, name, collectable)
        end)
      {:suspended, item, stream} ->
        {name, item} = case router.(item) do
          {n, i} -> {n, i}
          n -> {n, item}
        end
        collectable = collectables
        |> get_collectable(name, factory)
        |> Nile.Utils.put({:cont, item})
        collectables = Map.put(collectables, name, collectable)
        consume(stream, router, factory, collectables)
    end
  end

  defp get_collectable(collectables, name, factory) do
    case Map.get(collectables, name) do
      nil ->
        factory.(name)
      collectable ->
        collectable
    end
  end
end
