require_relative '../lib/ruby_zmq_framework'

# Binds to 5556, connects to 5555
bus = RubyZmqFramework::ZeroMQBus.new(5556, [5555])

class TelemetryStream
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
  end

  def handle_message(topic, payload)
    if topic == :engine_data
      puts "[Telemetry] Processing RPM: #{payload[:rpm]}"

      if payload[:rpm] > 6000
        puts "[Telemetry] OVER-REV DETECTED! Commanding throttle cut..."
        broadcast(:throttle_request, { position: 50 })
      end
    end
  end
end

telemetry = TelemetryStream.new(bus)
bus.subscribe(:engine_data, telemetry)

puts "Telemetry Node Online... (Listening for ECU data)"
sleep # Keeps the thread alive to listen
