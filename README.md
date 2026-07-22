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
2.  **Peer-to-Peer Bus:** `RubyZmqFramework::ZeroMQBus` acts as a decentralized message broker. Modules bind to a local port to publish data and connect to peer ports to subscribe to data. There is no dynamic discovery — every node's port has to be listed in every peer's `peer_ports` array up front.
3.  **Cross-Process Communication:** Modules do not need to run in the same Ruby script. They communicate entirely over TCP sockets.
4.  **Auto-Heartbeat:** Every `FrameworkModule` node automatically broadcasts a `:heartbeat` (`node_name`, `status`, `timestamp`) every 5 seconds in a background thread, with no extra code required.
5.  **State Registry:** `RubyZmqFramework::StateRegistry` is a passive, in-memory node that caches heartbeats and telemetry from whatever topics it's subscribed to, and replays its whole store as a `:global_state_snapshot` broadcast whenever it sees a `:request_global_state` message. It never blocks and never crashes when a peer goes quiet — a silent node's entry in `active_nodes` simply stops getting a fresher timestamp.

## Project Layout

```
lib/ruby_zmq_framework.rb                 # Entrypoint, requires the rest of the gem
lib/ruby_zmq_framework/version.rb         # Gem version
lib/ruby_zmq_framework/framework.rb       # StrictContract + FrameworkModule (incl. heartbeat)
lib/ruby_zmq_framework/zeromq_bus.rb      # ZeroMQBus
lib/ruby_zmq_framework/state_registry.rb  # StateRegistry
lib/ruby_zmq_framework/can_bridge.rb      # CanBridge (SocketCAN -> bus)
examples/                                 # Runnable example nodes (examples/python/ for the Python ones)
test/                                     # Minitest suite (`rake test`)
python/ruby_zmq_framework/                # Python counterpart: ZeroMQBus + FrameworkNode
python/tests/                             # unittest suite for the Python side
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

## State Registry Example

`run_state_registry.rb` binds to 5558 and caches heartbeats/telemetry from the ECU, Telemetry, Web Bridge, Dashboard Consumer, and CAN Bridge nodes, printing a snapshot every 5 seconds:
```bash
bundle exec ruby examples/run_state_registry.rb
```

`run_dashboard_consumer.rb` demonstrates the consumer side of the pattern: it broadcasts `:request_global_state` on startup and caches whatever `:global_state_snapshot` comes back:
```bash
bundle exec ruby examples/run_dashboard_consumer.rb
```

## CAN Bridge Example (real hardware)

`run_can_bridge.rb` reads raw frames off a real SocketCAN interface (`can0` by default, or set `CAN_IFACE`) using Ruby's built-in `Socket` class plus a couple of raw ioctl calls — no extra CAN gem required — and rebroadcasts each frame as `:can_frame` (`id`, `extended`, `dlc`, `data`):
```bash
CAN_IFACE=can0 bundle exec ruby examples/run_can_bridge.rb
```
This needs an actual CAN or virtual CAN (`vcan0`) interface present on the machine; it fails fast with the underlying `Errno` (e.g. `ENODEV`) if the interface doesn't exist.

## Python Nodes (e.g. a `cantools`-based DBC decoder)

The bus is just two-frame `[topic, json_payload]` ZeroMQ pub/sub, so non-Ruby processes can join it directly. `python/ruby_zmq_framework/` is a small, wire-compatible counterpart to the gem: `ZeroMQBus` mirrors the Ruby class, and `FrameworkNode` mirrors `FrameworkModule` — subclass it, implement `handle_message(topic, payload)`, and you get the same automatic `:heartbeat` broadcast every 5 seconds for free, so a `StateRegistry` node sees Python processes in `active_nodes` exactly like Ruby ones.

**Prerequisite:**
```bash
pip install -r python/requirements.txt   # just pyzmq
```

`examples/python/run_dbc_decoder.py` is a stand-in for a real `cantools`-based DBC decoder: it binds to 5561, connects to the State Registry (5558), and broadcasts decoded signals under a topic per DBC message name (e.g. `engine_data`).
```bash
python3 examples/python/run_dbc_decoder.py
```
Run it alongside `run_state_registry.rb` (whose `peer_ports` already includes 5561) and you'll see the Python node's heartbeat and telemetry show up in the registry's snapshots.

Python tests: `python -m unittest discover -s python/tests`.

**Note on ZeroMQ sockets and threads:** a PUB socket must not be written to concurrently from multiple threads without synchronization — `FrameworkNode`'s heartbeat thread and your own code both publish through it, so `ZeroMQBus.publish` takes a lock around every send. Keep that in mind if you build anything that touches `_pub`/`_sub` directly instead of going through `publish`/`subscribe`.
