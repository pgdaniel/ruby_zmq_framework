require 'ffi-rzmq'
require 'json'

module RubyZmqFramework
  class ZeroMQBus
    # How long the listener blocks in poll before looping, in milliseconds.
    POLL_TIMEOUT_MS = 100

    def initialize(my_port, peer_ports = [])
      @context = ZMQ::Context.new

      # Publisher Socket
      @pub = @context.socket(ZMQ::PUB)
      check! @pub.bind("tcp://127.0.0.1:#{my_port}"), "bind to port #{my_port}"

      # Subscriber Socket
      @sub = @context.socket(ZMQ::SUB)
      peer_ports.each { |p| check! @sub.connect("tcp://127.0.0.1:#{p}"), "connect to port #{p}" }
      check! @sub.setsockopt(ZMQ::SUBSCRIBE, ''), 'subscribe'

      @local_subscribers = Hash.new { |h, k| h[k] = [] }
      start_listener
    end

    def subscribe(topic, module_instance)
      @local_subscribers[topic.to_sym] << module_instance
    end

    def publish(topic, payload = {})
      check! @pub.send_strings([topic.to_s, payload.to_json]), "publish #{topic}"
    end

    private

    def check!(rc, action)
      return if ZMQ::Util.resultcode_ok?(rc)

      raise Error, "[Framework Error] ZeroMQ #{action} failed: #{ZMQ::Util.error_string}"
    end

    def start_listener
      Thread.new do
        poller = ZMQ::Poller.new
        poller.register_readable(@sub)

        loop do
          ready = poller.poll(POLL_TIMEOUT_MS)
          if ready == -1
            warn "[Framework Error] Listener poll failed: #{ZMQ::Util.error_string}"
            sleep 0.1
            next
          end
          next if ready.zero?

          messages = []
          unless ZMQ::Util.resultcode_ok?(@sub.recv_strings(messages))
            warn "[Framework Error] Listener receive failed: #{ZMQ::Util.error_string}"
            next
          end

          topic, json = messages
          # Drop anything that doesn't match the two-frame [topic, json] wire format.
          next if topic.nil? || json.nil?

          dispatch(topic, json)
        end
      end
    end

    # A bad payload or a raising subscriber must never kill the listener
    # thread: one poisoned message would otherwise leave the node deaf for
    # good while its heartbeat keeps reporting "ok".
    def dispatch(topic_str, json)
      subscribers = @local_subscribers[topic_str.to_sym]
      return if subscribers.empty?

      begin
        payload = JSON.parse(json, symbolize_names: true)
      rescue JSON::ParserError => e
        warn "[Framework Error] Dropping malformed payload on #{topic_str}: #{e.message}"
        return
      end

      topic = topic_str.to_sym
      subscribers.each do |mod|
        mod.handle_message(topic, payload)
      rescue StandardError => e
        warn "[Framework Error] #{mod.class} failed handling #{topic}: #{e.message}"
      end
    end
  end
end
