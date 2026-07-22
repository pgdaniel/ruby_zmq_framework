$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "minitest/autorun"
require "ruby_zmq_framework"

# A stand-in for ZeroMQBus that records what would have gone out over the
# wire, so FrameworkModule/StateRegistry logic can be tested without
# opening real sockets.
class FakeBus
  attr_reader :messages

  def initialize
    @messages = []
  end

  def publish(topic, payload = {})
    @messages << [topic, payload]
  end

  def find(topic)
    messages.find { |t, _| t == topic }
  end
end

# Polls until the block returns a truthy value or the timeout elapses.
# Used for assertions on the FrameworkModule heartbeat, which is fired
# from a background thread rather than synchronously.
def wait_for(timeout: 1.0)
  deadline = Time.now + timeout
  loop do
    result = yield
    return result if result
    return nil if Time.now > deadline

    sleep 0.01
  end
end
