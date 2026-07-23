require_relative '../lib/ruby_zmq_framework'

$stdout.sync = true

# Watches engine data and commands a throttle cut on over-rev.
# Publishes: throttle_request. Subscribes: engine_data.
class Telemetry
  include RubyZmqFramework::FrameworkModule

  OVER_REV_RPM = 6000

  def initialize(bus)
    @bus = bus
  end

  def handle_message(topic, payload)
    return unless topic == :engine_data

    puts "Processing RPM: #{payload[:rpm]}"
    return unless payload[:rpm] > OVER_REV_RPM

    puts 'OVER-REV DETECTED! Commanding throttle cut...'
    broadcast(:throttle_request, { position: 50 })
  end
end

RubyZmqFramework.boot(Telemetry)
puts 'online'
sleep
