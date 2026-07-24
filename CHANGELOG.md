# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Changed
- The repo is now a reference implementation of a flow-based,
  language-agnostic node runtime ("Node-RED without the UI"): the graph
  lives in `flow.yml`, `bin/flowctl` computes wiring and runs it, nodes
  are blackbox processes configured entirely from the environment, and
  `PROTOCOL.md` is the one-page contract for joining from any language.
  `examples/` (hand-wired scripts) became `nodes/` (env-wired processes).

### Added (flow runtime)
- `RubyZmqFramework.boot`: builds a node from `BUS_PORT`, `BUS_PEERS`,
  `BUS_SUBSCRIBES`, and `NODE_NAME`; standalone-friendly when unset.
- `RubyZmqFramework::Flow`: parses the manifest and computes each node's
  peer wiring from topic publishers/subscribers.
- `bin/flowctl` (with `--plan`): port assignment, spawning, prefixed
  output streaming, Ctrl-C teardown.
- `PROTOCOL.md`: transport, wire format, env contract, heartbeat schema,
  and a minimal Python node.

### Fixed
- The `ZeroMQBus` listener thread no longer dies silently on malformed
  JSON, non-two-frame messages, or exceptions raised inside a
  subscriber's `handle_message` — one bad message previously left the
  node permanently deaf while its heartbeat kept reporting "ok".
- Unknown topics arriving off the wire no longer grow the subscriber map
  without bound, and topic strings from the network are no longer
  interned into symbols unless someone subscribed to them.
- The `StrictContract` check now runs before construction, so a class
  missing a required method can no longer leak a live heartbeat thread
  from a failed `.new`. The contract also applies to subclasses.

### Added
- Local dispatch: messages published on a bus now reach subscribers on
  that same bus, with the same symbolized-key payload representation as
  wire delivery.
- Clean shutdown: `ZeroMQBus#close`, `FrameworkModule#stop_heartbeat`,
  and `CanBridge#close`.
- Configurable endpoints: `bind_host:` keyword, peers as `"host:port"`
  or full ZeroMQ endpoints, and `my_port = 0` for an OS-assigned
  ephemeral port (readable via `ZeroMQBus#port`).
- `FrameworkModule#node_name`: set `@node_name` to give each node a
  distinct heartbeat identity.
- ZeroMQ return codes are checked; failures raise
  `RubyZmqFramework::Error` instead of passing silently.

## [0.1.1] - 2026-07-24

### Fixed
- `bin/flowctl` is now actually packaged with the gem (registered as the
  `flowctl` executable) instead of only existing in the git checkout —
  previously a project that merely depended on the gem had no way to run
  the Quick Start despite the README instructing `bundle exec bin/flowctl`.
  `PROTOCOL.md` is shipped alongside it for the same reason.
- `bin/flowctl` resolved its nodes' working directory from its own
  install location (`__dir__`) rather than the manifest it was given, so
  a `flow.yml` outside this repo would spawn nodes that couldn't find
  their own relative `cmd` paths. It now `chdir`s to the manifest's
  directory.

## [0.1.0] - 2026-07-21

- Initial version: `ZeroMQBus`, `StrictContract`, `FrameworkModule`
  auto-heartbeat, `StateRegistry`, `CanBridge`, examples, tests.
