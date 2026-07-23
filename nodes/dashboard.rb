require_relative '../lib/ruby_zmq_framework'

$stdout.sync = true

# Consumer side of the async state-sync pattern: request the registry's
# snapshot once on startup, then cache whatever comes back.
# Publishes: request_global_state. Subscribes: global_state_snapshot.
class Dashboard
  include RubyZmqFramework::FrameworkModule

  attr_reader :global_state

  def initialize(bus)
    @bus = bus
    @global_state = {}
  end

  def handle_message(topic, payload)
    return unless topic == :global_state_snapshot

    @global_state = payload
    puts "Synced global state: #{@global_state.inspect}"
  end
end

dashboard = RubyZmqFramework.boot(Dashboard)
puts 'online'

sleep 1 # let PUB/SUB connections settle before the fire-and-forget request
dashboard.broadcast(:request_global_state, { requester: dashboard.node_name })
sleep
