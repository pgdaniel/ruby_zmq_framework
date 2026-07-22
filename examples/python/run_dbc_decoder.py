#!/usr/bin/env python3
"""
Stand-in for a real DBC-decoding script (e.g. one built on `cantools`).
Shows how any Python process can join the same ZeroMQ bus as the Ruby
nodes: subclass FrameworkNode, get automatic :heartbeat broadcasts for
free (so a StateRegistry sees it in active_nodes), and broadcast decoded
signals under whatever topic name matches the DBC message.
"""
import random
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "python"))

from ruby_zmq_framework import FrameworkNode, ZeroMQBus


class DbcDecoder(FrameworkNode):
    def handle_message(self, topic, payload):
        pass  # pure producer, nothing on the bus to react to

    def run(self):
        while True:
            # In a real decoder this would be cantools' db.decode_message()
            # output, keyed by DBC message name.
            self.broadcast("engine_data", {"rpm": random.randint(2000, 7000)})
            time.sleep(1)


if __name__ == "__main__":
    # Binds to 5561, connects to the State Registry (5558) so it shows up
    # in active_nodes and its telemetry gets cached there too.
    bus = ZeroMQBus(5561, peer_ports=[5558])
    decoder = DbcDecoder(bus)

    print("DBC Decoder Node Online... (broadcasting :engine_data)", flush=True)
    decoder.run()
