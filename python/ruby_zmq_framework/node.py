import time
import threading
from abc import ABC, abstractmethod


class FrameworkNode(ABC):
    """Python counterpart to RubyZmqFramework::FrameworkModule.

    Subclasses must implement handle_message(topic, payload); Python's
    ABC machinery enforces that at instantiation time, the same "raise
    the moment .new/__init__ is called" contract StrictContract enforces
    on the Ruby side.

    Just like the Ruby side, a background thread broadcasts a
    "heartbeat" ({node_name, status, timestamp}) every HEARTBEAT_INTERVAL
    seconds once self.bus is set, so any node built on this base is
    automatically visible to a StateRegistry without extra code.
    """

    HEARTBEAT_INTERVAL = 5  # seconds

    def __init__(self, bus):
        self.bus = bus
        self._start_heartbeat()

    @abstractmethod
    def handle_message(self, topic, payload):
        raise NotImplementedError

    def broadcast(self, topic, payload=None):
        self.bus.publish(topic, payload or {})

    def _start_heartbeat(self):
        def loop():
            while True:
                try:
                    self.broadcast("heartbeat", {
                        "node_name": type(self).__name__,
                        "status": "ok",
                        "timestamp": int(time.time()),
                    })
                except Exception as e:
                    print(f"[Framework Error] Heartbeat failed for {type(self).__name__}: {e}")
                time.sleep(self.HEARTBEAT_INTERVAL)

        thread = threading.Thread(target=loop, daemon=True)
        thread.start()
