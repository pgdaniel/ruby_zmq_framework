require_relative '../lib/ruby_zmq_framework'

interface = ENV.fetch('CAN_IFACE', 'can0')

# Binds to 5560. Connect to the State Registry's port too (5558) if you
# want :can_frame telemetry to show up in its snapshots — remember to add
# 5560 to the registry's own peer_ports and `bus.subscribe(:can_frame, ...)`
# there, since ZeroMQBus has no dynamic peer discovery.
bus = RubyZmqFramework::ZeroMQBus.new(5560, [5558])

RubyZmqFramework::CanBridge.new(bus, interface: interface)

puts "CAN Bridge Node Online... (reading #{interface}, broadcasting :can_frame)"
sleep
