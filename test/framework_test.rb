require_relative "test_helper"

class ContractlessNode
  include RubyZmqFramework::StrictContract
  requires_methods(:handle_message)
end

class CompliantNode
  include RubyZmqFramework::FrameworkModule

  attr_reader :bus

  def initialize(bus)
    @bus = bus
  end

  def handle_message(topic, payload); end
end

class StrictContractTest < Minitest::Test
  def test_raises_when_a_required_method_is_missing
    error = assert_raises(NotImplementedError) { ContractlessNode.new }
    assert_match(/handle_message/, error.message)
  end

  def test_succeeds_when_the_required_method_is_present
    node = CompliantNode.new(FakeBus.new)
    assert_instance_of CompliantNode, node
  end
end

class FrameworkModuleTest < Minitest::Test
  def test_requires_handle_message
    assert_includes CompliantNode.required_methods, :handle_message
  end

  def test_broadcast_delegates_to_bus_publish
    bus = FakeBus.new
    node = CompliantNode.new(bus)
    node.broadcast(:custom_topic, { foo: "bar" })

    assert_includes bus.messages, [:custom_topic, { foo: "bar" }]
  end

  def test_heartbeat_starts_automatically_after_initialize
    bus = FakeBus.new
    CompliantNode.new(bus)

    heartbeat = wait_for { bus.find(:heartbeat) }
    refute_nil heartbeat, "expected a :heartbeat message shortly after initialize"

    _, payload = heartbeat
    assert_equal "CompliantNode", payload[:node_name]
    assert_equal "ok", payload[:status]
    assert_kind_of Integer, payload[:timestamp]
  end
end
