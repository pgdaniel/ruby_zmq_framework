require_relative "ruby_zmq_framework/version"
require_relative "ruby_zmq_framework/framework"
require_relative "ruby_zmq_framework/zeromq_bus"
require_relative "ruby_zmq_framework/state_registry"
require_relative "ruby_zmq_framework/can_bridge"
require_relative "ruby_zmq_framework/flow"

module RubyZmqFramework
  class Error < StandardError; end

  # Boots a node the flow-runtime way: all bus wiring comes from
  # environment variables (set by bin/flowctl, or by hand), so node code
  # never contains ports, peer lists, or subscription calls — a node is
  # just a class with handle_message plus whatever it broadcasts.
  #
  #   BUS_PORT        port to bind (default 0 = OS-assigned ephemeral)
  #   BUS_PEERS       comma-separated peer endpoints ("127.0.0.1:5555,...")
  #   BUS_SUBSCRIBES  comma-separated topics routed to node#handle_message
  #   NODE_NAME       heartbeat identity (defaults to the class name)
  #
  # node_class must take the bus as its first constructor argument. With
  # no environment set, the node still boots standalone on an ephemeral
  # port — handy for poking at a single node in isolation.
  def self.boot(node_class, *args, **kwargs)
    bus = ZeroMQBus.new(ENV.fetch('BUS_PORT', '0').to_i, env_list('BUS_PEERS'))
    node = node_class.new(bus, *args, **kwargs)
    env_list('BUS_SUBSCRIBES').each { |topic| bus.subscribe(topic, node) }

    # Booted nodes are processes managed by a supervisor (bin/flowctl) or a
    # terminal: exit quietly on TERM/INT instead of dumping a backtrace
    # from an interrupted sleep. Frameworks that install their own traps
    # afterwards (e.g. Sinatra) simply override these.
    %w[TERM INT].each { |sig| trap(sig) { exit } }
    node
  end

  def self.env_list(key)
    ENV.fetch(key, '').split(',').map(&:strip).reject(&:empty?)
  end
  private_class_method :env_list
end
