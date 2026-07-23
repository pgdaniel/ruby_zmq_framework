require_relative '../lib/ruby_zmq_framework'

$stdout.sync = true # so flowctl's per-line prefixing sees output live

# Simulated engine unit. Publishes: engine_data. Subscribes: throttle_request.
class Ecu
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
  end

  def handle_message(topic, payload)
    puts "Received throttle command: #{payload[:position]}%" if topic == :throttle_request
  end
end

ecu = RubyZmqFramework.boot(Ecu)
puts 'online'

sleep 1 # let PUB/SUB connections settle before the first broadcast
loop do
  rpm = rand(2000..7000)
  puts "Broadcasting RPM: #{rpm}"
  ecu.broadcast(:engine_data, { rpm: rpm })
  sleep 1
end
