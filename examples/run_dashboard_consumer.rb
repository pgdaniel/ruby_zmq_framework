require_relative '../lib/ruby_zmq_framework'

# Binds to 5559, connects to the State Registry
bus = RubyZmqFramework::ZeroMQBus.new(5559, [5558])

# Example consumer that follows the async state-sync pattern: request the
# registry's snapshot on startup, then cache whatever it sends back.
class DashboardConsumer
  include RubyZmqFramework::FrameworkModule

  attr_reader :global_state

  def initialize(bus)
    @bus = bus
    @global_state = {}
    sleep 1 # Allow ZMQ to handshake before the fire-and-forget request
    broadcast(:request_global_state, { requester: self.class.name })
  end

  def handle_message(topic, payload)
    if topic == :global_state_snapshot
      @global_state = payload
      puts "[Dashboard] Synced global state: #{@global_state.inspect}"
    end
  end
end

consumer = DashboardConsumer.new(bus)
bus.subscribe(:global_state_snapshot, consumer)

puts "Dashboard Consumer Online... (waiting for global state)"
sleep
