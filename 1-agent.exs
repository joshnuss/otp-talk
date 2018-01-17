defmodule Grid do
  @name __MODULE__

  def start_link do
    Agent.start_link(fn -> %{} end, name: @name)
  end

  def join(id, coordinates) do
    update &Map.put_new(&1, id, coordinates)
  end

  def move(id, coordinates) do
    update &Map.put(&1, id, coordinates)
  end

  def leave(id) do
    update &Map.delete(&1, id)
  end

  defp update(fun) do
    Agent.update(@name, fun)
  end
end

Grid.start_link |> IO.inspect

:sys.trace(Grid, true)

Grid.join(:josh, {10, 20}) |> IO.inspect
Grid.join(:hugo, {11, 20}) |> IO.inspect

Grid.move(:josh, {10, 21})

Grid.leave(:josh)
