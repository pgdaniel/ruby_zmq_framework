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
        inherited = superclass.respond_to?(:required_methods) ? superclass.required_methods : []
        inherited | (@required_methods || [])
      end

      # The check runs BEFORE super (i.e. before allocate/initialize), so a
      # violating class never gets partially constructed. This matters for
      # FrameworkModule: its prepended Heartbeat starts a broadcasting thread
      # inside initialize, and checking afterwards would leak that thread
      # from a zombie instance whose .new appeared to fail.
      def new(...)
        missing = required_methods.reject do |m|
          method_defined?(m) || private_method_defined?(m)
        end
        if missing.any?
          raise NotImplementedError,
                "[Framework Error] Contract Violation: #{self} missing #{missing.join(', ')}"
        end
        super
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
      def initialize(...)
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
