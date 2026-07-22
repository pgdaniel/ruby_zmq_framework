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

# Exercises the listener against traffic a well-behaved framework peer would
# never send: raw single-frame messages and non-JSON payloads. The listener
# thread must survive all of it and keep delivering later valid messages.
class ZeroMQBusResilienceTest < Minitest::Test
  def setup
    @raw_context = ZMQ::Context.new
    @raw_pub = @raw_context.socket(ZMQ::PUB)
    raw_port = free_port
    @raw_pub.bind("tcp://127.0.0.1:#{raw_port}")

    @bus = RubyZmqFramework::ZeroMQBus.new(free_port, [raw_port])
    @received = Queue.new
    recorder = @received
    @listener = Object.new
    @listener.define_singleton_method(:handle_message) do |topic, payload|
      recorder << [topic, payload]
    end
  end

  def teardown
    @raw_pub.setsockopt(ZMQ::LINGER, 0)
    @raw_pub.close
    @raw_context.terminate
  end

  def test_listener_survives_malformed_and_short_messages
    @bus.subscribe(:ping, @listener)
    sleep 0.3 # slow-joiner

    @raw_pub.send_string("lonely-frame")            # not two frames
    @raw_pub.send_strings(["ping", "not json {"])   # unparseable payload
    @raw_pub.send_strings(["ping", '{"seq":2}'])    # valid — must still arrive

    topic, payload = Timeout.timeout(3) { @received.pop }
    assert_equal :ping, topic
    assert_equal({ seq: 2 }, payload)
  end

  def test_unknown_topics_do_not_grow_the_subscriber_map
    @bus.subscribe(:ping, @listener)
    sleep 0.3 # slow-joiner

    50.times { |i| @raw_pub.send_strings(["noise_#{i}", "{}"]) }
    @raw_pub.send_strings(["ping", '{"seq":4}'])

    # ZMQ preserves per-connection ordering, so once :ping arrives all the
    # noise topics have already been through the dispatch path.
    Timeout.timeout(3) { @received.pop }
    assert_equal ["ping"], @bus.instance_variable_get(:@local_subscribers).keys
  end

  def test_a_raising_subscriber_does_not_starve_the_others
    angry = Object.new
    angry.define_singleton_method(:handle_message) { |_t, _p| raise "boom" }

    @bus.subscribe(:ping, angry)
    @bus.subscribe(:ping, @listener) # subscribed after, dispatched after
    sleep 0.3 # slow-joiner

    @raw_pub.send_strings(["ping", '{"seq":3}'])

    topic, payload = Timeout.timeout(3) { @received.pop }
    assert_equal :ping, topic
    assert_equal({ seq: 3 }, payload)
  end
end
