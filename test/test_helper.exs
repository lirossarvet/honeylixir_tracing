defmodule DateTimeFake do
  def utc_now(), do: ~U[2020-09-24 04:15:19.345808Z]
end

defmodule HoneylixirTestListener do
  @moduledoc """
  Small `Agent` used to store and retrieve fields to be added to all events.
  """
  use Agent

  @doc false
  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def enqueue_event(%Honeylixir.Event{} = event) do
    Agent.update(__MODULE__, fn state -> [event | state] end)
  end

  def clear() do
    Agent.update(__MODULE__, fn _ -> [] end)
  end

  def values() do
    Agent.get(__MODULE__, & &1)
  end
end

defmodule HoneylixirTestStubbedRepo do
  def config() do
    %{database: "whatever_dev"}
  end
end

:ok = Application.ensure_loaded(:plug)
ExUnit.start()
