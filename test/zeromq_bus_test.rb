require_relative "test_helper"
require "timeout"

class ZeroMQBusTest < Minitest::Test
  def test_a_published_message_reaches_a_connected_peer
    port_a = 15_551
    port_b = 15_552

    bus_a = RubyZmqFramework::ZeroMQBus.new(port_a, [port_b])
    bus_b = RubyZmqFramework::ZeroMQBus.new(port_b, [port_a])

    received = Queue.new
    listener = Object.new
    listener.define_singleton_method(:handle_message) do |topic, payload|
      received << [topic, payload]
    end
    bus_b.subscribe(:ping, listener)

    sleep 0.3 # give the PUB/SUB sockets time to connect (slow-joiner)
    bus_a.publish(:ping, { seq: 1 })

    topic, payload = Timeout.timeout(3) { received.pop }
    assert_equal :ping, topic
    assert_equal({ seq: 1 }, payload)
  end
end
