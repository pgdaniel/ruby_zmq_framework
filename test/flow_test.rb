require_relative "test_helper"

class FlowTest < Minitest::Test
  SPEC = {
    "nodes" => {
      "ecu" => {
        "cmd" => "ruby nodes/ecu.rb",
        "publishes" => ["engine_data"],
        "subscribes" => ["throttle_request"]
      },
      "telemetry" => {
        "cmd" => "ruby nodes/telemetry.rb",
        "publishes" => ["throttle_request"],
        "subscribes" => ["engine_data"]
      },
      "registry" => {
        "cmd" => "ruby nodes/state_registry.rb",
        "subscribes" => %w[heartbeat engine_data],
        "env" => { "VERBOSE" => "1" }
      }
    }
  }.freeze

  PORTS = { "ecu" => 5001, "telemetry" => 5002, "registry" => 5003 }.freeze

  def wiring
    @wiring ||= RubyZmqFramework::Flow.new(SPEC).wiring(PORTS)
  end

  def test_peers_are_computed_from_topic_publishers
    assert_equal "127.0.0.1:5002", wiring["ecu"]["BUS_PEERS"]
    assert_equal "127.0.0.1:5001", wiring["telemetry"]["BUS_PEERS"]
  end

  def test_heartbeat_makes_every_node_a_publisher_except_yourself
    peers = wiring["registry"]["BUS_PEERS"].split(",").sort
    assert_equal %w[127.0.0.1:5001 127.0.0.1:5002], peers
  end

  def test_each_node_gets_its_own_port_name_and_subscriptions
    assert_equal "5001", wiring["ecu"]["BUS_PORT"]
    assert_equal "ecu", wiring["ecu"]["NODE_NAME"]
    assert_equal "heartbeat,engine_data", wiring["registry"]["BUS_SUBSCRIBES"]
  end

  def test_custom_env_is_merged_into_the_wiring
    assert_equal "1", wiring["registry"]["VERBOSE"]
  end

  def test_a_deaf_subscription_warns_but_does_not_raise
    spec = { "nodes" => { "lonely" => { "cmd" => "true", "subscribes" => ["ghost_topic"] } } }
    _out, err = capture_io { RubyZmqFramework::Flow.new(spec) }
    assert_match(/ghost_topic/, err)
  end

  def test_a_node_without_cmd_is_rejected
    spec = { "nodes" => { "broken" => { "publishes" => ["x"] } } }
    error = assert_raises(RubyZmqFramework::Error) { RubyZmqFramework::Flow.new(spec) }
    assert_match(/broken needs a cmd/, error.message)
  end

  def test_a_manifest_without_nodes_is_rejected
    assert_raises(RubyZmqFramework::Error) { RubyZmqFramework::Flow.new({}) }
  end
end
