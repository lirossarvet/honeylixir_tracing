defmodule HoneylixirTracing.SpanTest do
  use ExUnit.Case
  alias HoneylixirTracing.Span
  doctest HoneylixirTracing.Span

  setup do
    %{span: Span.setup("root-span-name", %{})}
  end

  describe "setup/2" do
    test "generates a span_id as Base16 lowercase", %{span: span} do
      assert Regex.match?(~r/[a-f0-9]{16}/, span.span_id)
    end

    test "uses current tracing data if available for parent_id and trace_id", %{span: parent_span} do
      HoneylixirTracing.Context.set_current_span(parent_span)

      child_span = Span.setup("child", %{})

      refute child_span.span_id == parent_span.span_id

      assert child_span.parent_id == parent_span.span_id
      assert child_span.trace_id == parent_span.trace_id

      teardown()
    end

    test "generates a trace_id if a trace hasn't already been started", %{span: span} do
      assert is_nil(span.parent_id)
      assert Regex.match?(~r/[a-f0-9]{16}/, span.trace_id)
    end

    test "sets the start_time to a monotonic timestamp", %{span: span} do
      # This doesn't really guarantee it's a monotonic timestamp, just an integer.
      # But at least helps ensure it's not a DateTime or something.
      assert is_integer(span.start_time)
    end

    test "adds the given name as a \"name\" field on the underlying event" do
      span = Span.setup("test for name", %{})

      assert span.event.fields["name"] == "test for name"
    end

    test "adds any other fields given to the underlying event" do
      span = Span.setup("whatever", %{"cool" => 1})

      assert span.event.fields["cool"] == 1
    end
  end

  describe "setup/3" do
    test "accepts propagation data" do
      prop = %HoneylixirTracing.Propagation{
        trace_id: "foo",
        parent_id: "bar",
        dataset: "cool-stuff"
      }

      span = Span.setup(prop, "neato", %{"val" => 1})

      assert span.parent_id == "bar"
      assert span.trace_id == "foo"
      assert span.event.dataset == "cool-stuff"
      assert span.event.fields["name"] == "neato"
      assert span.event.fields["val"] == 1
    end

    test "accepts nil and does nothing with it" do
      span = Span.setup(nil, "cool", %{"val" => 1})

      assert is_nil(span.parent_id)
      refute is_nil(span.trace_id)
      assert span.event.fields["name"] == "cool"
      assert span.event.fields["val"] == 1
    end
  end

  describe "send/1" do
    test "sends the underlying event with all span fields added", %{span: parent_span} do
      start_supervised!(HoneylixirTestListener)

      HoneylixirTracing.Context.set_current_span(parent_span)

      child_span = Span.setup("child", %{"field" => ["test_value"]})
      # Nobody likes this, but simulate a tiny amount of time for the child span
      :timer.sleep(5)

      Span.send(child_span)
      Span.send(parent_span)

      [parent_event, child_event] = HoneylixirTestListener.values()

      assert parent_event.fields["duration_ms"] >= 0.0
      assert child_event.fields["duration_ms"] >= 0.0

      refute is_nil(parent_event.fields["trace.trace_id"])
      refute is_nil(child_event.fields["trace.trace_id"])
      assert child_event.fields["trace.trace_id"] == parent_event.fields["trace.trace_id"]

      refute is_nil(parent_event.fields["trace.span_id"])
      refute is_nil(child_event.fields["trace.span_id"])

      assert is_nil(parent_event.fields["trace.parent_id"])
      refute is_nil(child_event.fields["trace.parent_id"])

      assert child_event.fields["field"] == ["test_value"]

      teardown()
    end
  end

  defp teardown() do
    Process.delete(:honeylixir_context)
    :ets.delete_all_objects(:honeylixir_tracing_context)
  end
end
