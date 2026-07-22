require 'ffi-rzmq'
require 'json'

module RubyZmqFramework
  class ZeroMQBus
    def initialize(my_port, peer_ports = [])
      @context = ZMQ::Context.new

      # Publisher Socket
      @pub = @context.socket(ZMQ::PUB)
      @pub.bind("tcp://127.0.0.1:#{my_port}")

      # Subscriber Socket
      @sub = @context.socket(ZMQ::SUB)
      peer_ports.each { |p| @sub.connect("tcp://127.0.0.1:#{p}") }
      @sub.setsockopt(ZMQ::SUBSCRIBE, '')

      @local_subscribers = Hash.new { |h, k| h[k] = [] }
      start_listener
    end

    def subscribe(topic, module_instance)
      @local_subscribers[topic.to_sym] << module_instance
    end

    def publish(topic, payload = {})
      @pub.send_strings([topic.to_s, payload.to_json])
    end

    private

    def start_listener
      Thread.new do
        loop do
          messages = []
          @sub.recv_strings(messages)
          next if messages.empty?

          topic = messages[0].to_sym
          payload = JSON.parse(messages[1], symbolize_names: true)

          @local_subscribers[topic].each do |mod|
            mod.handle_message(topic, payload)
          end
        end
      end
    end
  end
end
