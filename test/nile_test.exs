defmodule NileTest do
  use ExUnit.Case

  doctest Nile

  setup do
    seed = ExUnit.configuration()[:seed] || :erlang.phash2(:os.timestamp())
    :random.seed({0,0,seed})
    :ok
  end

  test "route_into" do
    out = 0..100
    |> Nile.route_into(fn(value) ->
      rem(value, 3)
    end, fn(_) ->
      []
    end)

    assert %{0 => [0, 3, 6, 9  | _],
             1 => [1, 4, 7, 10 | _],
             2 => [2, 5, 8, 11 | _]} = out
  end

  test "expand" do
    out = 0..10
    |> Nile.expand(fn(value) ->
      [value, value]
    end)
    |> Enum.to_list()

    assert [0,0,1,1,2,2,3,3,4,4,5,5 | _] = out
  end

  test "pmap" do
    out = 0..100
    |> Nile.pmap(fn(value) ->
      :timer.sleep(value * :random.uniform(20))
      value
    end)
    |> Enum.to_list

    assert out == 0..100 |> Enum.to_list()
  end

  test "split" do
    size = :random.uniform(200)

    out = Stream.repeatedly(fn -> "line\n" end)
    |> Stream.take(size)
    |> Stream.chunk_by(fn (_) -> :random.uniform(2) == 1 end)
    |> Nile.String.split()
    |> Enum.to_list

    assert length(out) == size
  end

  test "rescue" do
    [first | _] = out = Stream.repeatedly(fn ->
      raise RuntimeError
    end)
    |> Nile.Exception.rescue_stream(RuntimeError, fn(e) -> e end)
    |> Enum.take(5)

    assert length(out) == 5
    assert first == %RuntimeError{}
  end
end
