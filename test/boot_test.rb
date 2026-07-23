require_relative "test_helper"

class BootedNode
  include RubyZmqFramework::FrameworkModule

  attr_reader :bus, :seen

  def initialize(bus)
    @bus = bus
    @seen = Queue.new
  end

  def handle_message(topic, payload)
    @seen << [topic, payload]
  end
end

class BootTest < Minitest::Test
  ENV_KEYS = %w[BUS_PORT BUS_PEERS BUS_SUBSCRIBES NODE_NAME].freeze

  def setup
    @saved_env = ENV_KEYS.to_h { |k| [k, ENV[k]] }
    ENV_KEYS.each { |k| ENV.delete(k) }
  end

  def teardown
    @saved_env.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
    @node&.stop_heartbeat
    @node&.bus&.close
  end

  def test_boot_wires_a_node_entirely_from_the_environment
    ENV["BUS_SUBSCRIBES"] = "ping, pong"
    ENV["NODE_NAME"] = "node-7"

    @node = RubyZmqFramework.boot(BootedNode)

    assert_operator @node.bus.port, :>, 0
    assert_equal "node-7", @node.node_name

    # Subscriptions came from BUS_SUBSCRIBES; local dispatch is synchronous.
    @node.bus.publish(:ping, { seq: 1 })
    assert_equal [:ping, { seq: 1 }], @node.seen.pop(true)
  end

  def test_boot_with_an_empty_environment_still_runs_standalone
    @node = RubyZmqFramework.boot(BootedNode)

    assert_operator @node.bus.port, :>, 0
    assert_equal "BootedNode", @node.node_name

    # Nothing subscribed, so publishes go nowhere — but must not raise.
    @node.bus.publish(:ping, { seq: 2 })
    assert @node.seen.empty?
  end

  def test_booted_peers_reach_each_other_over_the_wire
    upstream = RubyZmqFramework.boot(BootedNode)

    ENV["BUS_PEERS"] = "127.0.0.1:#{upstream.bus.port}"
    ENV["BUS_SUBSCRIBES"] = "ping"
    @node = RubyZmqFramework.boot(BootedNode)

    sleep 0.3 # slow-joiner
    upstream.bus.publish(:ping, { seq: 3 })

    require "timeout"
    assert_equal [:ping, { seq: 3 }], Timeout.timeout(3) { @node.seen.pop }
  ensure
    upstream&.stop_heartbeat
    upstream&.bus&.close
  end
end
