defmodule Grid do
  @name __MODULE__

  def start_link do
    Agent.start_link(fn -> %{} end, name: @name)
  end

  def join(id, coordinates) do
    Agent.update(@name, &Map.put_new(&1, id, coordinates))
  end

  def move(id, coordinates) do
    Agent.update(@name, &Map.put(&1, id, coordinates))
  end

  def leave(id) do
    Agent.update(@name, &Map.delete(&1, id))
  end
end

Grid.start_link |> IO.inspect

Grid.join(:mike, {10, 20}) |> IO.inspect
Grid.join(:sally, {11, 20}) |> IO.inspect

Grid.move(:mike, {10, 21})

Grid.leave(:mike)
