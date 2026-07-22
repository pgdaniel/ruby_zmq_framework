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
    def self.included(base)
      base.include(StrictContract)
      base.requires_methods(:handle_message)
    end

    def broadcast(topic, payload = {})
      @bus.publish(topic, payload)
    end
  end
end
