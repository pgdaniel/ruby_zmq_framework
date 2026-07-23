require 'ffi-rzmq'
require 'json'
require 'monitor'

module RubyZmqFramework
  class ZeroMQBus
    # How long the listener blocks in poll before looping, in milliseconds.
    POLL_TIMEOUT_MS = 100

    # The port actually bound — differs from my_port when my_port is 0.
    attr_reader :port

    # my_port may be 0 to bind an OS-assigned ephemeral port (read it back
    # via #port). peer_ports entries may be Integers (loopback ports),
    # "host:port" strings, or full ZeroMQ endpoints ("tcp://10.0.0.5:5555").
    # Pass bind_host: "0.0.0.0" to accept peers from other machines.
    def initialize(my_port, peer_ports = [], bind_host: '127.0.0.1')
      @context = ZMQ::Context.new

      # Publisher Socket
      @pub = @context.socket(ZMQ::PUB)
      bind_endpoint = "tcp://#{bind_host}:#{my_port.to_i.zero? ? '*' : my_port}"
      check! @pub.bind(bind_endpoint), "bind to #{bind_endpoint}"
      @port = bound_port

      # Subscriber Socket
      @sub = @context.socket(ZMQ::SUB)
      peer_ports.each do |peer|
        endpoint = peer_endpoint(peer)
        check! @sub.connect(endpoint), "connect to #{endpoint}"
      end
      check! @sub.setsockopt(ZMQ::SUBSCRIBE, ''), 'subscribe'

      # Keyed by topic *string*, with no default proc: the listener looks up
      # every topic that arrives off the wire, and a defaulting hash would
      # insert a permanent empty entry per unknown topic — an unbounded,
      # network-driven leak. A Monitor guards it because subscribe runs on
      # the caller's thread while dispatch runs on the listener thread.
      @local_subscribers = {}
      @subscribers_lock = Monitor.new
      @running = true
      start_listener
    end

    # Stops the listener thread and releases both sockets and the context.
    # Stop anything still publishing on this bus first (heartbeats, reader
    # threads): publishing on a closed bus raises RubyZmqFramework::Error.
    # Idempotent.
    def close
      return if @closed

      @closed = true
      @running = false
      @listener.join(POLL_TIMEOUT_MS / 1000.0 + 1) unless Thread.current == @listener

      [@sub, @pub].each do |sock|
        sock.setsockopt(ZMQ::LINGER, 0)
        sock.close
      end
      @context.terminate
      nil
    end

    def subscribe(topic, module_instance)
      @subscribers_lock.synchronize do
        (@local_subscribers[topic.to_s] ||= []) << module_instance
      end
    end

    def publish(topic, payload = {})
      json = payload.to_json
      check! @pub.send_strings([topic.to_s, json]), "publish #{topic}"

      # A SUB socket never connects back to its own PUB, so without this,
      # two modules sharing one bus in the same process could not hear each
      # other. Delivering the serialized form keeps the payload
      # representation identical whether a message arrived locally or over
      # the wire (string keys become symbols either way).
      dispatch(topic.to_s, json)
    end

    private

    def check!(rc, action)
      return if ZMQ::Util.resultcode_ok?(rc)

      raise Error, "[Framework Error] ZeroMQ #{action} failed: #{ZMQ::Util.error_string}"
    end

    def bound_port
      endpoint = []
      check! @pub.getsockopt(ZMQ::LAST_ENDPOINT, endpoint), 'read bound endpoint'
      # ffi-rzmq returns the endpoint with a trailing NUL, e.g. "tcp://127.0.0.1:5555\0"
      endpoint.first.delete("\0").rpartition(':').last.to_i
    end

    def peer_endpoint(peer)
      case peer
      when Integer then "tcp://127.0.0.1:#{peer}"
      when %r{\A[a-z]+://} then peer # already a full ZeroMQ endpoint
      else "tcp://#{peer}"           # "host:port"
      end
    end

    def start_listener
      @listener = Thread.new do
        poller = ZMQ::Poller.new
        poller.register_readable(@sub)

        while @running
          ready = poller.poll(POLL_TIMEOUT_MS)
          if ready == -1
            break unless @running

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
    # Runs entirely inside the Monitor, which is reentrant: dispatch happens
    # on the listener thread AND on whichever thread called publish, and
    # serializing them guarantees a subscriber's handle_message is never
    # executed concurrently — while a handler that publishes from within
    # handle_message simply re-enters the lock it already holds.
    def dispatch(topic_str, json)
      @subscribers_lock.synchronize do
        subscribers = @local_subscribers[topic_str]
        return if subscribers.nil? || subscribers.empty?

        begin
          payload = JSON.parse(json, symbolize_names: true)
        rescue JSON::ParserError => e
          warn "[Framework Error] Dropping malformed payload on #{topic_str}: #{e.message}"
          return
        end

        topic = topic_str.to_sym
        # Dup so a handler that subscribes mid-dispatch can't mutate the
        # list we're iterating.
        subscribers.dup.each do |mod|
          mod.handle_message(topic, payload)
        rescue StandardError => e
          warn "[Framework Error] #{mod.class} failed handling #{topic}: #{e.message}"
        end
      end
    end
  end
end
