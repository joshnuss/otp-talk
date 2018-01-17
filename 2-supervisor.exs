defmodule Tile do
  use Agent

  def start_link(name, coordinates) do
    Agent.start_link(fn -> %{} end, name: name)
  end

  def join(name, id, coordinates) do
    Agent.update(name, &Map.put_new(&1, id, coordinates))
  end

  def move(name, id, coordinates) do
    Agent.update(name, &Map.put(&1, id, coordinates))
  end

  def leave(name, id) do
    Agent.update(name, &Map.delete(&1, id))
  end
end

defmodule Grid do
  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok) do
    tiles() |> Supervisor.init(strategy: :one_for_one)
  end

  def join(id, coordinates) do
    coordinates
    |> tile_name
    |> Tile.join(id, coordinates)
  end

  def move(id, coordinates) do
    coordinates
    |> tile_name
    |> Tile.move(id, coordinates)
  end

  def leave(id, coordinates) do
    coordinates
    |> tile_name
    |> Tile.leave(id)
  end

  defp tile_name({x, y}) do
    :"tile-#{:erlang.floor(x)}-#{:erlang.floor(y)}"
  end

  defp tiles do
    for x <- 0..10, y <- 0..10 do
      coordinates = {x, y}
      name = tile_name(coordinates)

      %{
        id: name,
        start: {Tile, :start_link, [name, coordinates]}
      }
    end
  end
end

Grid.start_link |> IO.inspect

Grid
|> Supervisor.which_children
|> Enum.each(fn {_name, pid, _type, _args} -> :sys.trace(pid, true) end)

Grid.join(:mike, {10, 10}) |> IO.inspect
Grid.join(:sally, {9, 10}) |> IO.inspect

Grid.move(:mike, {10.4, 4})
Grid.leave(:mike, {10, 4})
