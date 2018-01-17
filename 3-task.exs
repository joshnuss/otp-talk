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

  def nearby(name, coordinates, radius) do
    Agent.get(name, &find(&1, coordinates, radius))
  end

  defp find(state, origin, radius) do
    state
    |> Enum.into([])
    |> Enum.map(fn {id, coordinates} -> {id, coordinates, distance(origin, coordinates)} end)
    |> Enum.filter(fn {_, _, distance} -> distance <= radius end)
  end

  defp distance({x1, y1}, {x2, y2}) do
    :math.sqrt(:math.pow(x2 - x1, 2) + :math.pow(y2 - y1, 2))
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

  def nearby(coordinates, radius \\ 10) do
    surrounding(coordinates, radius)
    |> Enum.map(&Task.async(Tile, :nearby, [&1, coordinates, radius]))
    |> Enum.flat_map(&Task.await/1)
    |> Enum.sort(&comparator/2)
  end

  defp tile_name({x, y}) do
    :"tile-#{:erlang.floor(x)}-#{:erlang.floor(y)}"
  end

  defp tiles do
    for x <- -20..20, y <- -20..20 do
      coordinates = {x, y}
      name = tile_name(coordinates)

      %{
        id: name,
        start: {Tile, :start_link, [name, coordinates]}
      }
    end
  end

  defp comparator({_, _, a}, {_, _, b}), do: a <= b

  defp surrounding({x, y}, radius) do
    for i <- :erlang.floor(x - radius)..:erlang.floor(x + radius + 1),
      j <- :erlang.floor(y - radius)..:erlang.floor(y + radius + 1) do
      tile_name({i, j})
    end
  end
end

IO.puts "grid: starting"
Grid.start_link |> IO.inspect

IO.puts "mike: joins grid"
Grid.join(:mike, {10, 10}) |> IO.inspect

IO.puts "sally: joins grid"
Grid.join(:sally, {11.5, 10}) |> IO.inspect

IO.puts "grid: search near {10, 10}, radius=1.5"
Grid.nearby({10, 10}, 1.5) |> IO.inspect

IO.puts "mike: is leaving"
Grid.leave(:mike, {10, 10}) |> IO.inspect

IO.puts "grid: search near {10, 10}, radius=1.5"
Grid.nearby({10, 10}, 1.5) |> IO.inspect
