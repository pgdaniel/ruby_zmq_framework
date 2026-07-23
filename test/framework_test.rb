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

# Includes the full FrameworkModule but "forgets" handle_message, to prove
# a contract violation is caught before initialize can start the heartbeat.
class ForgetfulNode
  include RubyZmqFramework::FrameworkModule

  def initialize(bus)
    @bus = bus
  end
end

class StrictContractTest < Minitest::Test
  def test_raises_when_a_required_method_is_missing
    error = assert_raises(NotImplementedError) { ContractlessNode.new }
    assert_match(/handle_message/, error.message)
  end

  def test_the_contract_applies_to_subclasses_too
    subclass = Class.new(ContractlessNode)
    error = assert_raises(NotImplementedError) { subclass.new }
    assert_match(/handle_message/, error.message)
  end

  def test_a_violating_framework_module_never_starts_its_heartbeat
    bus = FakeBus.new
    assert_raises(NotImplementedError) { ForgetfulNode.new(bus) }

    sleep 0.05 # a leaked heartbeat thread would broadcast immediately
    assert_empty bus.messages, "no heartbeat may leak from a failed .new"
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

  def test_heartbeat_uses_a_custom_node_name_when_set
    bus = FakeBus.new
    node_class = Class.new(CompliantNode) do
      def initialize(bus, name)
        @node_name = name
        super(bus)
      end
    end
    node_class.new(bus, "ecu-2")

    heartbeat = wait_for { bus.find(:heartbeat) }
    refute_nil heartbeat
    assert_equal "ecu-2", heartbeat[1][:node_name]
  end

  def test_stop_heartbeat_terminates_the_heartbeat_thread
    bus = FakeBus.new
    node = CompliantNode.new(bus)
    refute_nil wait_for { bus.find(:heartbeat) }

    thread = node.instance_variable_get(:@heartbeat_thread)
    node.stop_heartbeat

    refute thread.alive?, "heartbeat thread must exit promptly on stop"
    node.stop_heartbeat # idempotent: a second stop must not raise
  end
end
