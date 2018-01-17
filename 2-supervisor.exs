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

IO.puts "grid: starting"
Grid.start_link |> IO.inspect

:sys.trace(:"tile-10-10", true)
:sys.trace(:"tile-9-10", true)

IO.puts "mike: joins grid"
Grid.join(:mike, {10, 10}) |> IO.inspect

IO.puts "sally: joins grid"
Grid.join(:sally, {9, 10}) |> IO.inspect

IO.puts "mike: is on the move"
Grid.move(:mike, {10.4, 10}) |> IO.inspect

IO.puts "mike: is leaving"
Grid.leave(:mike, {10, 10}) |> IO.inspect
