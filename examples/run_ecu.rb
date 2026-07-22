require_relative '../lib/ruby_zmq_framework'

# Binds to 5555, connects to 5556
bus = RubyZmqFramework::ZeroMQBus.new(5555, [5556])

class EngineControlUnit
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
  end

  def handle_message(topic, payload)
    if topic == :throttle_request
      puts "[ECU] Received throttle command: #{payload[:position]}%"
    end
  end

  def run
    loop do
      rpm = rand(2000..7000)
      puts "[ECU] Broadcasting RPM: #{rpm}"
      broadcast(:engine_data, { rpm: rpm })
      sleep 1
    end
  end
end

ecu = EngineControlUnit.new(bus)
bus.subscribe(:throttle_request, ecu)

puts "ECU Node Online... (Listening for telemetry commands)"
sleep 1 # Allow ZMQ to handshake
ecu.run
