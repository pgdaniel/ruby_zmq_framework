require_relative '../lib/ruby_zmq_framework'

# Binds to 5558, connects to the ECU, Telemetry, Web Bridge, Dashboard
# Consumer, CAN Bridge, and Python DBC Decoder publishers.
# NOTE: ZeroMQBus has no dynamic peer discovery, so any node that will
# publish something the registry needs to see (a heartbeat, telemetry, or
# a :request_global_state) must have its port listed here too, or its
# messages never reach us.
bus = RubyZmqFramework::ZeroMQBus.new(5558, [5555, 5556, 5557, 5559, 5560, 5561])

registry = RubyZmqFramework::StateRegistry.new(bus)

# Local dispatch means the registry hears its own heartbeat too, so
# StateRegistry lists itself in active_nodes alongside remote peers.
bus.subscribe(:heartbeat, registry)
bus.subscribe(:engine_data, registry)
bus.subscribe(:can_frame, registry)
bus.subscribe(:request_global_state, registry)

puts "State Registry Node Online... (caching heartbeats + telemetry)"

loop do
  sleep 5
  puts "---- Global State Snapshot ----"
  pp registry.store
end
