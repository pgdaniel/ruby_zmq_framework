module RubyZmqFramework
  # A passive, in-memory cache of cluster-wide state. It listens to
  # heartbeats and telemetry broadcast by other FrameworkModule nodes and,
  # on request, replays its current snapshot back onto the bus. It never
  # makes a blocking call and never crashes when a peer goes quiet — a
  # silent node simply stops getting its active_nodes timestamp updated.
  class StateRegistry
    include FrameworkModule

    attr_reader :store

    def initialize(bus)
      @bus = bus
      @store = { active_nodes: {}, telemetry: {} }
    end

    def handle_message(topic, payload)
      case topic
      when :heartbeat
        @store[:active_nodes][payload[:node_name]] = {
          status: payload[:status],
          timestamp: payload[:timestamp]
        }
      when :request_global_state
        broadcast(:global_state_snapshot, @store)
      else
        @store[:telemetry][topic] = payload
      end
    end
  end
end
