import json
import threading
from collections import defaultdict

import zmq


class ZeroMQBus:
    """Python counterpart to RubyZmqFramework::ZeroMQBus. Wire-compatible:
    each message is a two-frame [topic, json_payload] multipart send, so
    Ruby and Python nodes can freely publish to / subscribe from each
    other on the same bus.
    """

    def __init__(self, my_port, peer_ports=None):
        peer_ports = peer_ports or []
        self._context = zmq.Context.instance()

        self._pub = self._context.socket(zmq.PUB)
        self._pub.bind(f"tcp://127.0.0.1:{my_port}")

        self._sub = self._context.socket(zmq.SUB)
        for port in peer_ports:
            self._sub.connect(f"tcp://127.0.0.1:{port}")
        self._sub.setsockopt_string(zmq.SUBSCRIBE, "")

        self._local_subscribers = defaultdict(list)
        # A PUB socket isn't safe for concurrent use: the heartbeat thread
        # and whatever thread the caller broadcasts from (usually main)
        # both write to self._pub, so every send needs to be serialized.
        self._pub_lock = threading.Lock()
        self._start_listener()

    def subscribe(self, topic, handler):
        self._local_subscribers[topic].append(handler)

    def publish(self, topic, payload=None):
        message = [topic.encode("utf-8"), json.dumps(payload or {}).encode("utf-8")]
        with self._pub_lock:
            self._pub.send_multipart(message)

    def _start_listener(self):
        def loop():
            while True:
                topic_bytes, payload_bytes = self._sub.recv_multipart()
                topic = topic_bytes.decode("utf-8")
                payload = json.loads(payload_bytes.decode("utf-8"))

                for handler in self._local_subscribers[topic]:
                    handler.handle_message(topic, payload)

        thread = threading.Thread(target=loop, daemon=True)
        thread.start()
