require_relative '../lib/ruby_zmq_framework'

$stdout.sync = true

# Relays raw SocketCAN frames onto the bus. Publishes: can_frame.
# Needs a real or virtual CAN interface (set CAN_IFACE, default can0);
# fails fast with the underlying Errno if it doesn't exist.
interface = ENV.fetch('CAN_IFACE', 'can0')
RubyZmqFramework.boot(RubyZmqFramework::CanBridge, interface: interface)
puts "online (reading #{interface}, broadcasting :can_frame)"
sleep
