require 'sinatra'
require_relative '../lib/ruby_zmq_framework'

$stdout.sync = true

# Global state shared between the bus dispatch thread and Sinatra web threads.
# Demo-only shortcut: written and read with no lock. That's tolerable for two
# scalar fields on MRI, but real code should wrap shared state in a Mutex.
$latest_telemetry = { rpm: 0, status: 'Waiting for data...' }

# HTTP bridge onto the bus: shows live telemetry, sends commands back.
# Publishes: throttle_request. Subscribes: engine_data.
class WebBridge
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
  end

  def handle_message(topic, payload)
    return unless topic == :engine_data

    $latest_telemetry[:rpm] = payload[:rpm]
    $latest_telemetry[:status] = 'Live'
  end
end

bridge = RubyZmqFramework.boot(WebBridge)
puts 'online'

set :port, ENV.fetch('WEB_PORT', '4567').to_i
set :bind, '0.0.0.0'

get '/' do
  erb :index
end

post '/command' do
  throttle_pos = params[:throttle].to_i
  bridge.broadcast(:throttle_request, { position: throttle_pos })
  puts "Broadcasted throttle command: #{throttle_pos}%"
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
  <!-- Refresh the page every 1 second to poll the latest state -->
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
