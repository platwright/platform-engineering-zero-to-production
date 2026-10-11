#!/usr/bin/env python3
"""Emit CORRELATED traces and logs for the Tempo lab.

Every iteration:
  1. builds a 3-span trace (checkout -> charge-card -> SELECT ledger),
  2. POSTs it to Tempo's OTLP/HTTP endpoint as OTLP JSON, and
  3. writes a matching structured log line carrying the SAME trace_id.

Because the log line and the trace share a trace_id, Grafana can jump from an
error log straight to its trace -- the whole point of the three pillars. Uses
only the Python standard library (no OTel SDK, no pip install).

Note: in OTLP/JSON, trace_id and span_id are HEX strings (a deliberate spec
exception), and *UnixNano timestamps are strings.
"""

import json
import os
import random
import time
import urllib.error
import urllib.request

OTLP_TRACES_URL = os.environ.get("OTLP_TRACES_URL", "http://tempo:4318/v1/traces")
LOG_DIR = "/var/log/app"
LOG_PATH = os.path.join(LOG_DIR, "app.log")

MS = 1_000_000  # nanoseconds per millisecond
ROUTES = ["/checkout", "/cart", "/pay"]

STATUS_UNSET, STATUS_OK, STATUS_ERROR = 0, 1, 2
KIND_SERVER, KIND_CLIENT = 2, 3


def hex_id(n_bytes: int) -> str:
    return "%0*x" % (n_bytes * 2, random.getrandbits(n_bytes * 8))


def span(trace_id, span_id, name, kind, start_ns, end_ns,
         parent_id=None, attributes=None, status_code=STATUS_UNSET):
    s = {
        "traceId": trace_id,
        "spanId": span_id,
        "name": name,
        "kind": kind,
        "startTimeUnixNano": str(start_ns),
        "endTimeUnixNano": str(end_ns),
        "status": {"code": status_code},
    }
    if parent_id:
        s["parentSpanId"] = parent_id
    if attributes:
        s["attributes"] = attributes
    return s


def attr(key, value):
    if isinstance(value, bool):
        return {"key": key, "value": {"boolValue": value}}
    if isinstance(value, int):
        return {"key": key, "value": {"intValue": str(value)}}
    return {"key": key, "value": {"stringValue": str(value)}}


def build_payload(is_error: bool, route: str, total_ms: float):
    trace_id = hex_id(16)
    root_id, charge_id, db_id = hex_id(8), hex_id(8), hex_id(8)
    now = time.time_ns()
    total = int(total_ms * MS)
    http_status = 500 if is_error else 200
    root_status = STATUS_ERROR if is_error else STATUS_OK

    root = span(
        trace_id, root_id, f"POST {route}", KIND_SERVER, now, now + total,
        attributes=[attr("http.method", "POST"), attr("http.route", route),
                    attr("http.status_code", http_status)],
        status_code=root_status,
    )
    charge = span(
        trace_id, charge_id, "charge-card", KIND_CLIENT,
        now + 20 * MS, now + total - 20 * MS, parent_id=root_id,
        attributes=[attr("peer.service", "payments")],
        status_code=root_status,
    )
    db = span(
        trace_id, db_id, "SELECT ledger", KIND_CLIENT,
        now + 50 * MS, now + total - 40 * MS, parent_id=charge_id,
        attributes=[attr("db.system", "postgresql"),
                    attr("db.statement", "SELECT * FROM ledger WHERE id = $1")],
    )

    payload = {
        "resourceSpans": [{
            "resource": {"attributes": [attr("service.name", "checkout")]},
            "scopeSpans": [{
                "scope": {"name": "lab-generator"},
                "spans": [root, charge, db],
            }],
        }]
    }
    return trace_id, http_status, payload


def post_trace(payload: dict) -> None:
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        OTLP_TRACES_URL, data=data,
        headers={"Content-Type": "application/json"}, method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            resp.read()
    except (urllib.error.URLError, TimeoutError) as exc:
        # Tempo may still be starting; keep going.
        print(f"trace post failed (will retry next loop): {exc}")


def main() -> None:
    os.makedirs(LOG_DIR, exist_ok=True)
    with open(LOG_PATH, "a", buffering=1, encoding="utf-8") as logf:
        while True:
            is_error = random.random() < 0.2
            route = random.choice(ROUTES)
            total_ms = round(random.uniform(120, 480), 1)

            trace_id, http_status, payload = build_payload(is_error, route, total_ms)
            post_trace(payload)

            logf.write(json.dumps({
                "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "level": "error" if is_error else "info",
                "service": "checkout",
                "route": route,
                "status": http_status,
                "latency_ms": total_ms,
                "trace_id": trace_id,
                "msg": "payment gateway timeout" if is_error else "request completed",
            }) + "\n")

            time.sleep(1)


if __name__ == "__main__":
    main()
