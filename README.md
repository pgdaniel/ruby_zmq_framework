# Ruby ZeroMQ Pub/Sub Framework

This is a lightweight, pure-Ruby framework for decoupling modules using a peer-to-peer ZeroMQ network. It enforces a strict module contract (similar to TypeScript interfaces) at runtime without requiring compilation or type-checkers like Sorbet.

## Prerequisites

You need the ZeroMQ library installed on your system.

```bash
# Ubuntu / Debian
sudo apt-get install libzmq3-dev

# macOS (Homebrew)
brew install zeromq
```

Then install the Ruby dependencies:
```bash
bundle install
```

## How It Works

1.  **Strict Contract:** Any class that includes `RubyZmqFramework::FrameworkModule` must implement a `handle_message(topic, payload)` method. If it does not, the framework raises a `NotImplementedError` the moment `.new` is called.
2.  **Peer-to-Peer Bus:** `RubyZmqFramework::ZeroMQBus` acts as a decentralized message broker. Modules bind to a local port to publish data and connect to peer ports to subscribe to data.
3.  **Cross-Process Communication:** Modules do not need to run in the same Ruby script. They communicate entirely over TCP sockets.

## Project Layout

```
lib/ruby_zmq_framework.rb            # Entrypoint, requires the rest of the gem
lib/ruby_zmq_framework/version.rb    # Gem version
lib/ruby_zmq_framework/framework.rb  # StrictContract + FrameworkModule
lib/ruby_zmq_framework/zeromq_bus.rb # ZeroMQBus
examples/                            # Runnable example nodes
```

## Running the Example

The `examples/` directory contains two nodes that talk to each other:
*   `run_ecu.rb`: Simulates an engine unit blasting out RPM data.
*   `run_telemetry.rb`: Listens to the RPM data and sends a command back if the RPM exceeds a threshold.

To see them communicate, open two separate terminal windows.

**Terminal 1:**
```bash
bundle exec ruby examples/run_telemetry.rb
```

**Terminal 2:**
```bash
bundle exec ruby examples/run_ecu.rb
```

You should see the ECU start broadcasting and the Telemetry node reacting in real-time.

## Web App Example (Sinatra)

We've included a lightweight web bridge that acts as a node on the ZeroMQ bus. It listens to the telemetry data and provides an HTTP endpoint to trigger commands. Sinatra is installed as part of `bundle install` (see the `:examples` group in the `Gemfile`).

**Running the Web Node:**
Open a third terminal window while the ECU is running:
```bash
bundle exec ruby examples/run_webapp.rb
```
Then navigate to `http://localhost:4567` in your browser. You will see real-time RPM data populating the HTML and can use the UI to send a kill command back through the ZeroMQ network.
