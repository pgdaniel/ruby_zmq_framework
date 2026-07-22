require 'sinatra'
require_relative '../lib/ruby_zmq_framework'

# Global state to share between the ZeroMQ background thread and Sinatra web threads
$latest_telemetry = { rpm: 0, status: 'Waiting for data...' }

# 1. Define our Web Bridge Node using our strict contract
class WebBridge
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
  end

  # Fulfills the strict contract to listen to the bus
  def handle_message(topic, payload)
    if topic == :engine_data
      $latest_telemetry[:rpm] = payload[:rpm]
      $latest_telemetry[:status] = 'Live'
    end
  end
end

# 2. Spin up the ZeroMQ connection before starting the web server
# Bind to 5557, connect to the ECU on 5555
zmq_bus = RubyZmqFramework::ZeroMQBus.new(5557, [5555])
bridge = WebBridge.new(zmq_bus)

# Subscribe to engine data
zmq_bus.subscribe(:engine_data, bridge)
puts "Web Bridge ZMQ Node Online..."

# 3. Sinatra Web Server Configuration
set :port, 4567
set :bind, '0.0.0.0'

# A simple GET route to view the live data
get '/' do
  erb :index
end

# A POST route to send commands back down the ZeroMQ bus
post '/command' do
  throttle_pos = params[:throttle].to_i
  
  # Broadcast onto the ZeroMQ network
  bridge.broadcast(:throttle_request, { position: throttle_pos })
  
  puts "[Web] Broadcasted throttle command: #{throttle_pos}%"
  redirect '/'
end

__END__

@@ index
<!DOCTYPE html>
<html>
<head>
  <title>ZMQ Telemetry Dashboard</title>
  <style>
    body { font-family: system-ui, sans-serif; background: #111; color: #eee; padding: 2rem; }
    .card { background: #222; padding: 1.5rem; border-radius: 8px; max-width: 400px; margin-bottom: 1rem;}
    h1 { margin-top: 0; color: #4ade80; }
    button { background: #ef4444; color: white; border: none; padding: 10px 15px; border-radius: 5px; cursor: pointer; }
    button:hover { background: #dc2626; }
  </style>
  <!-- Refresh the page every 1 second to poll the latest ZMQ state -->
  <meta http-equiv="refresh" content="1">
</head>
<body>
  <div class="card">
    <h1>Telemetry Dashboard</h1>
    <p><strong>Status:</strong> <%= $latest_telemetry[:status] %></p>
    <p><strong>RPM:</strong> <span style="font-size: 1.5em; font-weight: bold;"><%= $latest_telemetry[:rpm] %></span></p>
  </div>

  <div class="card">
    <h2>Overrides</h2>
    <form action="/command" method="POST">
      <input type="hidden" name="throttle" value="0">
      <button type="submit">Send Engine Kill (0% Throttle)</button>
    </form>
  </div>
</body>
</html>