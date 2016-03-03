defmodule Nile.Exception do
  def rescue_stream(stream, exception, handler) do
    Stream.resource(
      fn -> {:streaming, stream} end,
      fn
        ({:empty, stream}) ->
          {:halt, stream}
        ({status, stream}) ->
          try do
            case Nile.Utils.next(stream) do
              {status, stream} when status in [:done, :halted] ->
                {[], {:empty, stream}}
              {:suspended, item, stream} ->
                {[item], {status, stream}}
            end
          catch
            :error, %{__struct__: ^exception} = e ->
              case handler.(e) do
                :halt ->
                  {[], {:empty, stream}}
                item ->
                  {[item], {status, stream}}
              end
          end
      end,
      fn (_) -> :ok end
    )
  end
end
