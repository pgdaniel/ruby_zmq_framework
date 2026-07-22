require_relative "test_helper"

class StateRegistryTest < Minitest::Test
  def setup
    @bus = FakeBus.new
    @registry = RubyZmqFramework::StateRegistry.new(@bus)
  end

  def test_starts_with_an_empty_store
    assert_equal({ active_nodes: {}, telemetry: {} }, @registry.store)
  end

  def test_heartbeat_updates_active_nodes
    @registry.handle_message(:heartbeat, { node_name: "Foo", status: "ok", timestamp: 123 })

    assert_equal({ status: "ok", timestamp: 123 }, @registry.store[:active_nodes]["Foo"])
  end

  def test_arbitrary_topic_is_cached_as_telemetry
    @registry.handle_message(:engine_data, { rpm: 4200 })

    assert_equal({ rpm: 4200 }, @registry.store[:telemetry][:engine_data])
  end

  def test_request_global_state_broadcasts_the_current_store
    @registry.handle_message(:heartbeat, { node_name: "Foo", status: "ok", timestamp: 123 })
    @registry.handle_message(:engine_data, { rpm: 4200 })
    @registry.handle_message(:request_global_state, { requester: "Dashboard" })

    topic, payload = @bus.find(:global_state_snapshot)
    refute_nil topic
    assert_equal @registry.store, payload
  end

  def test_an_offline_node_keeps_its_last_known_state_without_raising
    @registry.handle_message(:heartbeat, { node_name: "Foo", status: "ok", timestamp: 100 })
    @registry.handle_message(:heartbeat, { node_name: "Bar", status: "ok", timestamp: 100 })

    # "Bar" goes quiet: no further heartbeat arrives for it, only Foo's.
    @registry.handle_message(:heartbeat, { node_name: "Foo", status: "ok", timestamp: 200 })

    assert_equal 200, @registry.store[:active_nodes]["Foo"][:timestamp]
    assert_equal 100, @registry.store[:active_nodes]["Bar"][:timestamp]
  end
end
