defmodule Tile do
  use GenServer

  def start_link(name, origin) do
    state = %{
      name: name,
      origin: origin,
      records: %{}
    }

    GenServer.start_link(__MODULE__, state, name: name)
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call({:join, pid, coordinates}, _from, state) do
    record = %{
      position: coordinates,
      ref: Process.monitor(pid)
    }

    {:reply, :ok, put_in(state[:records][pid], record)}
  end

  def handle_call({:move, pid, coordinates}, _from, state) do
    {:reply, :ok, put_in(state[:records][pid][:position], coordinates)}
  end

  def handle_call({:leave, pid}, _from, state) do
    record = state.records[pid]
    Process.demonitor(record.ref)

    {:reply, :ok, %{state | records: Map.delete(state.records, pid)}}
  end

  def handle_call({:nearby, coordinates, radius}, _from, state) do
    nearby = find(state.records, coordinates, radius)

    {:reply, nearby, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | records: Map.delete(state.records, pid)}}
  end

  def join(tile, pid, coordinates) do
    GenServer.call(tile, {:join, pid, coordinates})
  end

  def move(tile, pid, coordinates) do
    GenServer.call(tile, {:move, pid, coordinates})
  end

  def leave(tile, pid) do
    GenServer.call(tile, {:leave, pid})
  end

  def nearby(tile, coordinates, radius) do
    GenServer.call(tile, {:nearby, coordinates, radius})
  end

  defp find(records, origin, radius) do
    records
    |> Enum.into([])
    |> Enum.map(fn {pid, %{position: position}} -> {pid, position, distance(origin, position)} end)
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

  def join(pid, coordinates) do
    coordinates
    |> tile_name
    |> Tile.join(pid, coordinates)
  end

  def move(pid, coordinates) do
    coordinates
    |> tile_name
    |> Tile.move(pid, coordinates)
  end

  def leave(pid, coordinates) do
    coordinates
    |> tile_name
    |> Tile.leave(pid)
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

defmodule Driver do
  use Agent

  def start(name) do
    Agent.start(fn -> %{name: name} end, name: name)
  end
end

Grid.start_link |> IO.inspect

Grid
|> Supervisor.which_children
|> Enum.each(fn {_name, pid, _type, _args} -> :sys.trace(pid, true) end)

{:ok, mike} = Driver.start(:mike)
{:ok, sally} = Driver.start(:sally)

Grid.join(mike, {10, 10}) |> IO.inspect
Grid.join(sally, {11.5, 10}) |> IO.inspect

Grid.nearby({10, 10}, 1.5) |> IO.inspect

Grid.move(mike, {10.4, 10})
Grid.leave(sally, {11.5, 10})

:timer.sleep(5000)

Process.exit(mike, true)
