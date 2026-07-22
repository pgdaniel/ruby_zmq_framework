import sys
import time
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ruby_zmq_framework import FrameworkNode


class FakeBus:
    """Records what would have gone out over the wire, so FrameworkNode
    logic can be tested without opening real sockets."""

    def __init__(self):
        self.messages = []

    def publish(self, topic, payload=None):
        self.messages.append((topic, payload or {}))

    def find(self, topic):
        return next((m for m in self.messages if m[0] == topic), None)


class Incomplete(FrameworkNode):
    pass


class Compliant(FrameworkNode):
    def handle_message(self, topic, payload):
        pass


class FrameworkNodeContractTest(unittest.TestCase):
    def test_raises_when_handle_message_is_missing(self):
        with self.assertRaises(TypeError):
            Incomplete(FakeBus())

    def test_succeeds_when_handle_message_is_present(self):
        node = Compliant(FakeBus())
        self.assertIsInstance(node, Compliant)


class FrameworkNodeBehaviorTest(unittest.TestCase):
    def test_broadcast_delegates_to_bus_publish(self):
        bus = FakeBus()
        node = Compliant(bus)
        node.broadcast("custom_topic", {"foo": "bar"})

        self.assertIn(("custom_topic", {"foo": "bar"}), bus.messages)

    def test_heartbeat_starts_automatically_after_init(self):
        bus = FakeBus()
        Compliant(bus)

        heartbeat = self._wait_for(lambda: bus.find("heartbeat"))
        self.assertIsNotNone(heartbeat, "expected a heartbeat message shortly after init")

        _, payload = heartbeat
        self.assertEqual(payload["node_name"], "Compliant")
        self.assertEqual(payload["status"], "ok")
        self.assertIsInstance(payload["timestamp"], int)

    def _wait_for(self, fn, timeout=1.0):
        deadline = time.time() + timeout
        while time.time() < deadline:
            result = fn()
            if result:
                return result
            time.sleep(0.01)
        return None


if __name__ == "__main__":
    unittest.main()
