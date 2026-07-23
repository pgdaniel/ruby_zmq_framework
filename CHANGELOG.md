# Changelog

All notable changes to this project are documented in this file.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

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

## [0.1.0] - 2026-07-21

- Initial version: `ZeroMQBus`, `StrictContract`, `FrameworkModule`
  auto-heartbeat, `StateRegistry`, `CanBridge`, examples, tests.
