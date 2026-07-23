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

> **Note:** the gem binds to ZeroMQ through [`ffi-rzmq`](https://github.com/chuckremes/ffi-rzmq), which is stable but hasn't seen a release in years. If you need libzmq features newer than ZeroMQ 4.x basics, look at `cztop` — the wire format here (plain two-frame PUB/SUB) works with any binding.

## How It Works

1.  **Strict Contract:** Any class that includes `RubyZmqFramework::FrameworkModule` must implement a `handle_message(topic, payload)` method. If it does not, the framework raises a `NotImplementedError` the moment `.new` is called.
2.  **Peer-to-Peer Bus:** `RubyZmqFramework::ZeroMQBus` acts as a decentralized message broker. Modules bind to a local port to publish data and connect to peer ports to subscribe to data. There is no dynamic discovery — every node's port has to be listed in every peer's `peer_ports` array up front. Peers can be Integers (loopback ports), `"host:port"` strings, or full ZeroMQ endpoints (`"tcp://10.0.0.5:5555"`); pass `bind_host: "0.0.0.0"` to accept peers from other machines, or `0` as your port to bind an OS-assigned ephemeral one (read it back via `bus.port`). Messages published on a bus are also delivered synchronously to subscribers on that same bus.
3.  **Cross-Process Communication:** Modules do not need to run in the same Ruby script. They communicate entirely over TCP sockets.
4.  **Auto-Heartbeat:** Every `FrameworkModule` node automatically broadcasts a `:heartbeat` (`node_name`, `status`, `timestamp`) every 5 seconds in a background thread, with no extra code required. The identity defaults to the class name — set `@node_name` in your `initialize` when running several instances of one class, or they will overwrite each other in a `StateRegistry`. Call `stop_heartbeat` to end it gracefully.
5.  **State Registry:** `RubyZmqFramework::StateRegistry` is a passive, in-memory node that caches heartbeats and telemetry from whatever topics it's subscribed to, and replays its whole store as a `:global_state_snapshot` broadcast whenever it sees a `:request_global_state` message. It never blocks and never crashes when a peer goes quiet — a silent node's entry in `active_nodes` simply stops getting a fresher timestamp.
6.  **Resilience:** The listener thread survives anything the network throws at it — non-framework frame layouts and malformed JSON are dropped with a warning, and each subscriber's `handle_message` is rescued individually so one raising handler can't starve the others (or kill the listener). ZeroMQ-level failures (bind, connect, publish) raise `RubyZmqFramework::Error` instead of failing silently. `handle_message` calls on one bus are serialized, so handlers never run concurrently.
7.  **Clean Shutdown:** `bus.close` stops the listener and releases the sockets and context; `node.stop_heartbeat` ends the heartbeat thread; `CanBridge#close` stops the whole bridge. Stop your nodes first, then close the bus — publishing on a closed bus raises `RubyZmqFramework::Error`.

## Project Layout

```
lib/ruby_zmq_framework.rb                 # Entrypoint, requires the rest of the gem
lib/ruby_zmq_framework/version.rb         # Gem version
lib/ruby_zmq_framework/framework.rb       # StrictContract + FrameworkModule (incl. heartbeat)
lib/ruby_zmq_framework/zeromq_bus.rb      # ZeroMQBus
lib/ruby_zmq_framework/state_registry.rb  # StateRegistry
lib/ruby_zmq_framework/can_bridge.rb      # CanBridge (SocketCAN -> bus)
examples/                                 # Runnable example nodes
test/                                     # Minitest suite (`rake test`)
```

The Python counterpart (`ZeroMQBus` + `FrameworkNode`, for e.g. a `cantools`-based DBC decoder) lives in a separate repo — see [Python Nodes](#python-nodes-eg-a-cantools-based-dbc-decoder) below.

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

The bus is just two-frame `[topic, json_payload]` ZeroMQ pub/sub, so non-Ruby processes can join it directly. A standalone Python library — `ZeroMQBus` and `FrameworkNode` (same automatic `:heartbeat`, so a `StateRegistry` node sees Python processes in `active_nodes` exactly like Ruby ones) — is interoperable with this gem over that shared wire format: **[python_zmq_framework](https://github.com/pgdaniel/python_zmq_framework)**.

Its example DBC-decoder stand-in binds to port 5561, which `run_state_registry.rb`'s `peer_ports` already includes, so the two repos' examples talk to each other out of the box.
