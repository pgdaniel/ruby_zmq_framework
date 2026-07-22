module RubyZmqFramework
  module StrictContract
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def requires_methods(*methods)
        @required_methods = methods
      end

      def required_methods
        @required_methods || []
      end

      def new(*args, &block)
        instance = super(*args, &block)
        missing = required_methods - instance.methods
        if missing.any?
          raise NotImplementedError,
                "[Framework Error] Contract Violation: #{self} missing #{missing.join(', ')}"
        end
        instance
      end
    end
  end

  module FrameworkModule
    HEARTBEAT_INTERVAL = 5 # seconds

    def self.included(base)
      base.include(StrictContract)
      base.requires_methods(:handle_message)
      base.prepend(Heartbeat)
    end

    # Prepended so it wraps whatever initialize the concrete module defines,
    # starting the heartbeat only once @bus has actually been assigned.
    module Heartbeat
      def initialize(*args, **kwargs, &block)
        super
        start_heartbeat
      end
    end

    def broadcast(topic, payload = {})
      @bus.publish(topic, payload)
    end

    private

    def start_heartbeat
      @heartbeat_thread = Thread.new do
        loop do
          begin
            broadcast(:heartbeat, {
              node_name: self.class.name,
              status: "ok",
              timestamp: Time.now.to_i
            })
          rescue StandardError => e
            warn "[Framework Error] Heartbeat failed for #{self.class.name}: #{e.message}"
          end
          sleep HEARTBEAT_INTERVAL
        end
      end
    end
  end
end
