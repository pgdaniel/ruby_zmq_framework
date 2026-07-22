import sys
import time
import queue
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from ruby_zmq_framework import ZeroMQBus


class ListenerNode:
    def __init__(self):
        self.received = queue.Queue()

    def handle_message(self, topic, payload):
        self.received.put((topic, payload))


class ZeroMQBusTest(unittest.TestCase):
    def test_a_published_message_reaches_a_connected_peer(self):
        port_a, port_b = 25_551, 25_552

        bus_a = ZeroMQBus(port_a, peer_ports=[port_b])
        bus_b = ZeroMQBus(port_b, peer_ports=[port_a])

        listener = ListenerNode()
        bus_b.subscribe("ping", listener)

        time.sleep(0.3)  # give the PUB/SUB sockets time to connect (slow-joiner)
        bus_a.publish("ping", {"seq": 1})

        topic, payload = listener.received.get(timeout=3)
        self.assertEqual(topic, "ping")
        self.assertEqual(payload, {"seq": 1})


if __name__ == "__main__":
    unittest.main()
