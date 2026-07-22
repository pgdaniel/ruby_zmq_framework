require_relative '../lib/ruby_zmq_framework'

# Binds to 5558, connects to the ECU, Telemetry, and Web Bridge publishers.
# NOTE: ZeroMQBus has no dynamic peer discovery, so any node that will
# broadcast :request_global_state (e.g. run_dashboard_consumer.rb on 5559)
# must have its port listed here too, or its request never reaches us.
bus = RubyZmqFramework::ZeroMQBus.new(5558, [5555, 5556, 5557, 5559])

registry = RubyZmqFramework::StateRegistry.new(bus)

bus.subscribe(:heartbeat, registry)
bus.subscribe(:engine_data, registry)
bus.subscribe(:request_global_state, registry)

puts "State Registry Node Online... (caching heartbeats + telemetry)"

loop do
  sleep 5
  puts "---- Global State Snapshot ----"
  pp registry.store
end
