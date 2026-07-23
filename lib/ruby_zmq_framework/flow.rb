require 'yaml'

module RubyZmqFramework
  # Parses a flow manifest (flow.yml) — the graph as data, Node-RED style.
  # The manifest is the ONLY place that knows the topology; node processes
  # learn their wiring from the environment variables computed here, and a
  # node's code never mentions another node.
  #
  #   nodes:
  #     ecu:
  #       cmd: ruby nodes/ecu.rb
  #       publishes: [engine_data]
  #       subscribes: [throttle_request]
  #       env: { SOME_KNOB: "42" }   # optional, merged into the process env
  class Flow
    Node = Struct.new(:name, :cmd, :publishes, :subscribes, :env, keyword_init: true)

    attr_reader :nodes

    def self.load(path)
      new(YAML.safe_load(File.read(path)))
    end

    def initialize(spec)
      unless spec.is_a?(Hash) && spec['nodes'].is_a?(Hash)
        raise Error, '[Framework Error] Flow manifest needs a top-level "nodes" map'
      end

      @nodes = spec['nodes'].map do |name, cfg|
        cfg ||= {}
        raise Error, "[Framework Error] Flow node #{name} needs a cmd" unless cfg['cmd']

        Node.new(
          name: name.to_s,
          cmd: cfg['cmd'],
          publishes: Array(cfg['publishes']).map(&:to_s),
          subscribes: Array(cfg['subscribes']).map(&:to_s),
          env: (cfg['env'] || {}).transform_values(&:to_s)
        )
      end
      warn_about_deaf_subscriptions
    end

    # The environment for every node process, given a {name => port} map.
    # This is the whole trick that keeps nodes blackboxes: each node's peer
    # list is computed from who publishes the topics it subscribes to.
    def wiring(ports)
      @nodes.to_h do |node|
        peers = peer_names(node).map { |name| "127.0.0.1:#{ports.fetch(name)}" }
        [node.name, {
          'BUS_PORT' => ports.fetch(node.name).to_s,
          'BUS_PEERS' => peers.join(','),
          'BUS_SUBSCRIBES' => node.subscribes.join(','),
          'NODE_NAME' => node.name
        }.merge(node.env)]
      end
    end

    private

    # Every FrameworkModule node broadcasts :heartbeat implicitly, so for
    # that topic everyone counts as a publisher. A node never peers with
    # itself — the bus already delivers its own publishes locally.
    def peer_names(node)
      node.subscribes
          .flat_map { |topic| publisher_names(topic) }
          .uniq - [node.name]
    end

    def publisher_names(topic)
      return @nodes.map(&:name) if topic == 'heartbeat'

      @nodes.select { |n| n.publishes.include?(topic) }.map(&:name)
    end

    def warn_about_deaf_subscriptions
      published = @nodes.flat_map(&:publishes).uniq + ['heartbeat']
      @nodes.each do |node|
        (node.subscribes - published).each do |topic|
          warn "[Framework Warning] #{node.name} subscribes to #{topic.inspect} but no node in the flow publishes it"
        end
      end
    end
  end
end
