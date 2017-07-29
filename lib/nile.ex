defmodule Nile do
  @doc """
  Expand each item into 0..n items

      iex> Nile.expand(0..10, &([&1, &1])) |> Enum.take(12)
      [0,0,1,1,2,2,3,3,4,4,5,5]
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
  Duplicate each element in a stream "n" times

      iex> Nile.duplicate(0..3, 3) |> Enum.take(12)
      [0,0,0,1,1,1,2,2,2,3,3,3]
  """
  def duplicate(stream, n \\ 2) do
    expand(stream, fn(item) ->
      Stream.repeatedly(fn -> item end)
      |> Stream.take(n)
    end)
  end

  @doc """
  Loop a stream repeatedly

      iex> Nile.repeat(0..3) |> Enum.take(10)
      [0,1,2,3,0,1,2,3,0,1]

      iex> Nile.repeat(0..3, 2) |> Enum.take(10)
      [0,1,2,3,0,1,2,3]
  """
  def repeat(stream, n \\ :infinity) do
    Stream.resource(
      fn -> 0 end,
      fn
        (count) when count < n ->
          {stream, count + 1}
        (count) ->
          {:halt, count}
      end,
      fn(_) -> :ok end
    )
  end

  @doc """
  Loop a stream with alternating directions

      iex> Nile.ping_pong(0..3) |> Enum.take(10)
      [0,1,2,3,2,1,0,1,2,3]

      iex> Nile.ping_pong(0..3, 1) |> Enum.take(10)
      [0,1,2,3,2,1]

      iex> Nile.ping_pong(0..3, 1, :inclusive) |> Enum.take(10)
      [0,1,2,3,3,2,1,0]
  """
  def ping_pong(stream, n \\ :infinity, mode \\ :exclusive) do
    Stream.resource(
      fn -> {stream, nil, 0} end,
      fn
        ({s, rev, count}) when count < n ->
          case Nile.Utils.next(s) do
            {status, _} when status in [:done, :halted] ->
              list = case mode do
                :exclusive ->
                  tl(rev)
                :inclusive ->
                  rev
              end
              {list, {stream, nil, count + 1}}
            {:suspended, item, s} when is_list(rev) ->
              {[item], {s, [item | rev], count}}
            {:suspended, item, s} when mode == :exclusive ->
              {[item], {s, [], count}}
            {:suspended, item, s} when mode == :inclusive ->
              {[item], {s, [item], count}}
          end
        (state) ->
          {:halt, state}
      end,
      fn({s, _, _}) -> Nile.Utils.halt(s) end
    )
  end

  @doc """
  Emit a sequence of values n times

      iex> Nile.emit(foo: 2, bar: 3) |> Enum.to_list()
      [:foo,:foo,:bar,:bar,:bar]
  """
  def emit(values) do
    values
    |> Stream.flat_map(fn({value, times}) ->
      Stream.repeatedly(fn -> value end)
      |> Stream.take(times)
    end)
  end

  @doc """
  Reset a stream with a control stream

      iex> 0..100 |> Nile.reset(Nile.emit(false: 3, true: 1) |> Nile.repeat()) |> Enum.take(10)
      [0,1,2,0,1,2,0,1,2,0]
  """
  def reset(source, control) do
    Stream.resource(
      fn -> {source, control} end,
      fn ({s, c}) ->
        case Nile.Utils.next(c) do
          {status, c} when status in [:done, :halted] ->
            {:halt, {s, c}}
          {:suspended, true, c} ->
            Nile.Utils.halt(s)
            {[], {source, c}}
          {:suspended, _, c} ->
            case Nile.Utils.next(s) do
              {status, s} when status in [:done, :halted] ->
                {:halt, {s, c}}
              {:suspended, item, s} ->
                {[item], {s, c}}
            end
        end
      end,
      fn({s, c}) ->
        Nile.Utils.halt(s)
        Nile.Utils.halt(c)
      end
    )
  end

  @doc """
  Concatenate streams lazily

      iex> Nile.lazy_concat(fn -> 1..3 end) |> Enum.take(9)
      [1,2,3,1,2,3,1,2,3]
  """
  def lazy_concat(fun) do
    Stream.resource(
      fn -> nil end,
      fn(s) ->
        case fun.() do
          nil ->
            {:halt, s}
          stream ->
            {stream, s}
        end
      end,
      fn(_) -> :ok end
    )
  end

  @doc """
  Concatenate streams lazily with state

      iex> Nile.lazy_concat(0, &{&1..&1+2, &1+1}) |> Enum.take(12)
      [0,1,2,1,2,3,2,3,4,3,4,5]
  """
  def lazy_concat(state, fun) do
    Stream.resource(
      fn -> state end,
      fn(s) ->
        case fun.(s) do
          nil ->
            {:halt, s}
          {stream, s} ->
            {stream, s}
        end
      end,
      fn(_) -> :ok end
    )
  end

  @doc """
  Merge a stream of streams with a function

      iex> [1..3, 4..7] |> Nile.merge(&Enum.sum/1) |> Enum.to_list()
      [5,7,9]
  """
  def merge(streams, fun) do
    Stream.resource(
      fn -> Enum.to_list(streams) end,
      fn (streams) ->
        streams
        |> Enum.map_reduce([], fn
          (stream, {:halt, acc}) ->
            {nil, {:halt, [stream | acc]}}
          (stream, acc) ->
            case Nile.Utils.next(stream) do
              {:suspended, v, stream} ->
                {v, [stream | acc]}
              {_status, stream} ->
                {nil, {:halt, [stream | acc]}}
            end
        end)
        |> case do
          {_, {:halt, streams}} ->
            {:halt, :lists.reverse(streams)}
          {values, streams} ->
            {[fun.(values)], :lists.reverse(streams)}
        end
      end,
      fn(streams) ->
        Enum.each(streams, &Nile.Utils.halt/1)
      end
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

      iex> Nile.pmap(0..26, fn(t) -> :timer.sleep(t); t end) |> Enum.take(5)
      [0,1,2,3,4]
  """
  defdelegate pmap(stream, fun, opts), to: Nile.Pmap

  @doc """
  Returns the identity of the stream
  """
  def identity(stream) do
    stream |> Stream.map(&(&1))
  end
end
