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

    # Identity used in heartbeats. Defaults to the class name, but set
    # @node_name in initialize when running several instances of the same
    # class — otherwise they overwrite each other in any StateRegistry's
    # active_nodes. Also covers anonymous classes, whose .name is nil.
    def node_name
      @node_name || self.class.name || 'AnonymousNode'
    end

    # Gracefully stops the heartbeat thread. Call this before closing the
    # bus the node broadcasts on. Wakes the thread out of its interval wait
    # rather than killing it, so an in-flight broadcast always completes.
    def stop_heartbeat
      thread = @heartbeat_thread
      return unless thread

      @heartbeat_mutex.synchronize do
        @heartbeat_running = false
        @heartbeat_wakeup.signal
      end
      thread.join(HEARTBEAT_INTERVAL + 1)
      @heartbeat_thread = nil
    end

    private

    def start_heartbeat
      @heartbeat_mutex = Mutex.new
      @heartbeat_wakeup = ConditionVariable.new
      @heartbeat_running = true

      @heartbeat_thread = Thread.new do
        loop do
          begin
            broadcast(:heartbeat, {
              node_name: node_name,
              status: "ok",
              timestamp: Time.now.to_i
            })
          rescue StandardError => e
            warn "[Framework Error] Heartbeat failed for #{node_name}: #{e.message}"
          end

          keep_going = @heartbeat_mutex.synchronize do
            @heartbeat_wakeup.wait(@heartbeat_mutex, HEARTBEAT_INTERVAL) if @heartbeat_running
            @heartbeat_running
          end
          break unless keep_going
        end
      end
    end
  end
end
