# ruby_zmq_framework

**Think Node-RED without the UI: a flow-based, language-agnostic runtime for
blackbox nodes wired together by topics.**

- **Nodes** are independent OS processes. Each one does one job, lives in one
  file, and knows nothing about any other node — not their ports, not their
  names, not their language.
- **Wires** are pub/sub topics carrying JSON, over ZeroMQ.
- **The graph is data**: [`flow.yml`](flow.yml) is the only artifact that
  knows the topology. `bin/flowctl` reads it, computes the wiring, and runs
  everything.
- **The contract is one page**: [`PROTOCOL.md`](PROTOCOL.md) is everything a
  node in any language needs to join.

The design goal is LLM-friendliness: each node is a task you can hand to an
agent with the protocol page and a one-line description ("write a Go node
that decodes DBC frames") — it never needs the rest of the repo in context.

## Quick start

You need the ZeroMQ library (`libzmq3-dev` on Debian/Ubuntu, `brew install
zeromq` on macOS), then:

```bash
bundle install
bundle exec bin/flowctl
```

That runs the demo graph from `flow.yml`: a simulated ECU blasting RPM data,
a telemetry node that commands a throttle cut on over-rev, a web dashboard
on <http://localhost:4567>, a state registry caching heartbeats and
telemetry, and a dashboard consumer syncing the registry's snapshot. Output
is streamed with a `[node_name]` prefix; Ctrl-C stops everything.

`bundle exec bin/flowctl --plan` prints the computed wiring without running
anything.

## Writing a node

A Ruby node is a class with one method, booted from the environment:

```ruby
require_relative '../lib/ruby_zmq_framework'
$stdout.sync = true

class RpmSmoother
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
    @window = []
  end

  def handle_message(topic, payload)
    @window = (@window << payload[:rpm]).last(5)
    broadcast(:engine_data_smooth, { rpm: @window.sum / @window.size })
  end
end

RubyZmqFramework.boot(RpmSmoother)
sleep
```

Note what's absent: no ports, no peers, no subscribe calls. Wiring comes
from environment variables (`BUS_PORT`, `BUS_PEERS`, `BUS_SUBSCRIBES`,
`NODE_NAME` — see `PROTOCOL.md`), which `flowctl` computes from the node's
entry in the manifest:

```yaml
  rpm_smoother:
    cmd: ruby nodes/rpm_smoother.rb
    subscribes: [engine_data]
    publishes: [engine_data_smooth]
```

Run standalone (no environment needed — it binds an ephemeral port) to poke
at a node in isolation: `bundle exec ruby nodes/rpm_smoother.rb`.

Every node automatically heartbeats every 5 seconds. `StrictContract`
raises at `.new` if a node forgets `handle_message` — loudly and
immediately, which is exactly the feedback an iterating agent needs.

## Nodes in other languages

The bus is just two-frame ZeroMQ pub/sub — `[topic, json]` — and the whole
contract fits on one page: [`PROTOCOL.md`](PROTOCOL.md), including a
complete minimal Python node. Follow it, add a `cmd` entry to `flow.yml`,
and the language never matters again. A Python companion library exists at
[python_zmq_framework](https://github.com/pgdaniel/python_zmq_framework)
(it predates the env-var contract; a node using it just reads the four
variables and passes them in).

## What's in the box

| piece | file | job |
|-------|------|-----|
| `ZeroMQBus` | `lib/ruby_zmq_framework/zeromq_bus.rb` | hardened transport: poison-message-proof listener, per-handler error isolation, local dispatch, clean `close` |
| `FrameworkModule` | `lib/ruby_zmq_framework/framework.rb` | node mixin: contract enforcement, auto-heartbeat, `broadcast`, `node_name`, `stop_heartbeat` |
| `Flow` | `lib/ruby_zmq_framework/flow.rb` | parses `flow.yml`, computes each node's env wiring |
| `flowctl` | `bin/flowctl` | assigns ports, spawns nodes, prefixes output, tears down |
| `StateRegistry` | `lib/ruby_zmq_framework/state_registry.rb` | passive cluster-state cache; replays snapshots on request |
| `CanBridge` | `lib/ruby_zmq_framework/can_bridge.rb` | real SocketCAN frames → `can_frame` topic (classic CAN, via raw ioctls, no extra gem) |
| demo nodes | `nodes/*.rb` | one blackbox process per file |

Delivery is fire-and-forget (latest-value-wins; slow consumers drop old
messages), handlers on one bus never run concurrently, and a bad message or
a raising handler can never kill a node's listener. See `CHANGELOG.md` for
the full hardening history.

> **Note:** ZeroMQ is reached through
> [`ffi-rzmq`](https://github.com/chuckremes/ffi-rzmq), which is stable but
> hasn't seen a release in years. The wire format is deliberately plain
> two-frame PUB/SUB, so swapping bindings — or the transport itself — stays
> a contained change behind the three-method bus interface
> (`publish`/`subscribe`/`close`).

## CAN hardware

Uncomment the `can_bridge` node in `flow.yml` (set `CAN_IFACE`, e.g.
`vcan0`) to relay real SocketCAN frames onto the bus as `can_frame`
messages. Needs an actual or virtual CAN interface; fails fast with the
underlying `Errno` if it doesn't exist.

## Tests

```bash
bundle exec rake test
```
