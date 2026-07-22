require_relative "test_helper"

class CanBridgeParseFrameTest < Minitest::Test
  # Builds a raw 16-byte struct can_frame: canid_t id (4B) + len (1B) +
  # pad/res0/len8_dlc (3B) + data[8] (8B), matching linux/can.h exactly.
  def build_frame(id_field, len, data_bytes)
    header = [id_field, len].pack("L< C")
    header + ("\x00" * 3) + (data_bytes + Array.new(8 - data_bytes.size, 0)).pack("C8")
  end

  def test_parses_a_standard_11_bit_frame
    raw = build_frame(0x123, 2, [0xDE, 0xAD])

    result = RubyZmqFramework::CanBridge.parse_frame(raw)

    assert_equal 0x123, result[:id]
    refute result[:extended]
    assert_equal 2, result[:dlc]
    assert_equal [0xDE, 0xAD], result[:data]
  end

  def test_parses_an_extended_29_bit_frame
    id_field = 0x1ABCDE | RubyZmqFramework::CanBridge::CAN_EFF_FLAG
    raw = build_frame(id_field, 4, [1, 2, 3, 4])

    result = RubyZmqFramework::CanBridge.parse_frame(raw)

    assert_equal 0x1ABCDE, result[:id]
    assert result[:extended]
    assert_equal [1, 2, 3, 4], result[:data]
  end

  def test_ignores_data_bytes_beyond_the_declared_length
    raw = build_frame(0x42, 3, [1, 2, 3, 99, 99, 99, 99, 99])

    result = RubyZmqFramework::CanBridge.parse_frame(raw)

    assert_equal [1, 2, 3], result[:data]
  end
end
