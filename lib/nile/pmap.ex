defmodule Nile.Pmap do
  @moduledoc false

  require Record
  Record.defrecordp :state, [stream: nil,
                             fun: nil,
                             opts: [],
                             timeout: :infinity,
                             concurrency: :infinity,
                             pending: []]

  def pmap(input, fun, opts \\ []) do
    Stream.resource(
      fn ->
        state(stream: input,
              fun: fun,
              opts: opts,
              timeout: opts[:timeout] || :infinity,
              concurrency: opts[:concurrency] || :infinity)
      end,
      &handle/1,
      fn(_) ->
        :ok
      end
    )
  end

  defp handle(state(stream: stream, fun: fun, pending: pending, concurrency: concurrency) = s) when concurrency == :infinity or length(pending) < concurrency do
    case Nile.Utils.next(stream) do
      {status, _} when status in [:done, :halted] ->
        await(state(s, stream: nil), state(s, :timeout))
      {:suspended, value, stream} ->
        task = Task.async(fn -> fun.(value) end)
        await(state(s, pending: pending ++ [task], stream: stream), 0)
    end
  end
  # we are at capacity
  defp handle(s) do
    await(s, state(s, :timeout))
  end

  defp await(state, timeout, next \\ &handle/1)
  defp await(state(pending: []) = s, _, _) do
    {:halt, s}
  end
  defp await(state(pending: [task = %Task{ref: ref} | pending]) = s, timeout, next) do
    receive do
      {^ref, value} ->
        Process.demonitor(ref, [:flush])
        {[value], state(s, pending: pending)}
      {:DOWN, ^ref, _, _, reason} ->
        error(s, task, reason)
    after
      timeout ->
        if timeout == 0 do
          next.(s)
        else
          Process.demonitor(ref, [:flush])
          args = [state(s, :stream), state(s, :fun), state(s, :opts)]
          exit({:timeout, {__MODULE__, :map, args}})
        end
    end
  end

  defp error(state(stream: stream, fun: fun, opts: opts), %Task{pid: pid}, :noconnection) do
    exit({{:nodedown, node(pid)}, {__MODULE__, :map, [stream, fun, opts]}})
  end
  defp error(state(stream: stream, fun: fun, opts: opts), %Task{}, reason) do
    exit({reason, {__MODULE__, :map, [stream, fun, opts]}})
  end
end
