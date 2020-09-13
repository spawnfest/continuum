defmodule Continuum.TelemetryTest do
  use ExUnit.Case, async: true
  import Continuum.QueueHelpers
  alias Continuum.FileSystem.Queue

  defmodule Continuum.TelemetryEventRecorder do
    def handle_event(
          [:queue | _rest] = event,
          measurements,
          metadata,
          _config
        ) do
      source = self()
      record = {event, measurements, metadata}

      Agent.update(Continuum.TelemetryEvents, fn events ->
        Map.update(events, source, [record], fn e -> [record | e] end)
      end)
    end
  end

  setup_all do
    Agent.start_link(fn -> Map.new() end, name: Continuum.TelemetryEvents)

    :ok =
      :telemetry.attach_many(
        "event-recorder",
        [[:queue, :length], [:queue, :push], [:queue, :pull]],
        &Continuum.TelemetryEventRecorder.handle_event/4,
        nil
      )

    on_exit(fn -> :telemetry.detach("event-recorder") end)

    :ok
  end

  test "queue length is reported to telemetry before a push" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)
    Queue.push(q, :message)
    assert find_event([:queue, :length], name)
  end

  test "pushes are reported to telemetry" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)
    Queue.push(q, :message)
    assert find_event([:queue, :push], name)
  end

  test "pulls are reported to telemetry" do
    name = unique_queue_name()
    q = Queue.init(root_dir: root_dir(), queue_name: name)
    Queue.push(q, :message)
    Queue.pull(q)
    assert find_event([:queue, :pull], name)
  end

  defp find_event(name, queue_name) do
    me = self()

    Agent.get(Continuum.TelemetryEvents, fn events ->
      events
      |> Map.get(me, [])
      |> Enum.find(fn {event, _measurements, metadata} ->
        event == name and metadata.queue_name == queue_name
      end)
    end)
  end
end
