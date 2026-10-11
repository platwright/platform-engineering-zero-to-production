#!/usr/bin/env python3
"""Feel metric cardinality before a backend feels it for you.

Cardinality = the number of unique time series a metric produces. It is the
PRODUCT of the cardinalities of every label. Low-cardinality labels (method,
status, route template) keep it bounded. One unbounded label (user_id, raw URL,
request id) multiplies it into the millions and melts the store.

Run:  python3 cardinality.py

Edit the `labels` dict to match your own service and re-run.
No third-party packages required.
"""

from functools import reduce


# Baseline: a realistic, well-behaved label scheme for one metric name.
# Each entry is label_name -> number of distinct values it can take.
labels = {
    "method": 4,     # GET, POST, PUT, DELETE
    "status": 5,     # 2xx, 3xx, 4xx, 5xx, other
    "route": 200,    # TEMPLATED routes: /users/{id}, never /users/42
    "pod": 50,       # replicas being scraped
}

# A high-cardinality label added "just to debug one thing" — the classic mistake.
USER_COUNT = 1_000_000


def series_count(label_cardinalities: dict[str, int]) -> int:
    """Total time series = product of all label cardinalities."""
    return reduce(lambda acc, n: acc * n, label_cardinalities.values(), 1)


def main() -> None:
    baseline = series_count(labels)
    with_userid = baseline * USER_COUNT

    print("label scheme:")
    for name, cardinality in labels.items():
        print(f"  {name:<8} -> {cardinality:>12,} distinct values")
    print()
    print(f"baseline series for ONE metric name : {baseline:>18,}")
    print(f"... after adding a user_id label     : {with_userid:>18,}")
    print()

    # A rough, order-of-magnitude rule of thumb for a single modest Prometheus.
    soft_limit = 2_000_000
    verdict = "OK" if baseline <= soft_limit else "DANGER"
    print(f"soft limit (single modest Prometheus): {soft_limit:>18,}  [{verdict}]")
    if with_userid > soft_limit:
        over = with_userid / soft_limit
        print(f"the user_id version is {over:,.0f}x over that limit -- do not ship it.")


if __name__ == "__main__":
    main()
