#!/usr/bin/env python3
"""Emit structured (JSON) logs for the Loki lab.

Writes one JSON object per line to /var/log/app/app.log, which Promtail tails.
The design mirrors the lesson: a FEW bounded fields become labels (service,
level), while high-cardinality detail (trace_id, route, status, latency_ms)
stays IN the line to be parsed by LogQL at query time.
"""

import json
import os
import random
import time
from datetime import datetime, timezone

LOG_DIR = "/var/log/app"
LOG_PATH = os.path.join(LOG_DIR, "app.log")

ROUTES = ["/", "/cart", "/pay", "/orders"]

# Weighted mix so most traffic is healthy, with a steady trickle of errors.
OUTCOMES = (
    [("info", 200, "request completed")] * 70
    + [("warn", 200, "slow upstream dependency")] * 15
    + [("error", 500, "payment gateway timeout")] * 10
    + [("error", 404, "resource not found")] * 5
)


def new_trace_id() -> str:
    """A random 32-hex-char id -- deliberately high-cardinality (stays in the line)."""
    return "%032x" % random.getrandbits(128)


def main() -> None:
    os.makedirs(LOG_DIR, exist_ok=True)
    # Line-buffered append so Promtail sees each line promptly.
    with open(LOG_PATH, "a", buffering=1, encoding="utf-8") as f:
        while True:
            level, status, msg = random.choice(OUTCOMES)
            record = {
                "ts": datetime.now(timezone.utc).isoformat(),
                "level": level,
                "service": "checkout",
                "route": random.choice(ROUTES),
                "status": status,
                "latency_ms": round(random.uniform(5, 350), 1),
                "trace_id": new_trace_id(),
                "msg": msg,
            }
            f.write(json.dumps(record) + "\n")
            time.sleep(0.3)


if __name__ == "__main__":
    main()
