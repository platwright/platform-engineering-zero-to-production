<!-- markdownlint-disable MD033 -->
# Signals worksheet — `checkout`

Fill in each `<placeholder>`. Be specific: name the measurement, its unit, and the
labels you would attach. Keep labels low-cardinality.

## Part A — RED (the service: `checkout`)

| Signal | Measurement | Unit | Labels (low-cardinality only) |
|--------|-------------|------|-------------------------------|
| Rate | `<e.g. http_requests_total, rate over 5m>` | `<req/s>` | `<route, method>` |
| Errors | `<e.g. 5xx requests over total>` | `<ratio or req/s>` | `<route, status>` |
| Duration | `<e.g. request latency histogram>` | `<seconds>` | `<route>` |

## Part B — USE (the resource: the node)

| Signal | Measurement | Unit | Notes |
|--------|-------------|------|-------|
| Utilization | `<e.g. CPU busy fraction>` | `<ratio>` | `<how busy>` |
| Saturation | `<e.g. run-queue length / memory pressure>` | `<count or ratio>` | `<queued work>` |
| Errors | `<e.g. NIC/disk errors>` | `<count>` | `<device errors>` |

## Part C — Four golden signals (user-facing `checkout`)

| Signal | Measurement | Percentiles / notes |
|--------|-------------|---------------------|
| Latency | `<success latency vs error latency>` | `<p50 / p95 / p99; why split success/fail>` |
| Traffic | `<requests per second>` | `<by route?>` |
| Errors | `<failed requests>` | `<which statuses count as errors?>` |
| Saturation | `<how close to a limit — queue depth, connections>` | `<which limit binds first?>` |

## Part D — Question → pillar

For each question, circle the pillar you reach for **first** and justify it.

| Question | Metrics / Logs / Traces | Why |
|----------|-------------------------|-----|
| Is the fleet-wide error rate rising? | `<pillar>` | `<why>` |
| What was the exact error message for order 8842? | `<pillar>` | `<why>` |
| Which downstream hop made this one request slow? | `<pillar>` | `<why>` |
| Are p99 latencies trending up this week? | `<pillar>` | `<why>` |
| Did this specific failed request retry payments? | `<pillar>` | `<why>` |

## Part E — Cardinality experiment (`cardinality.py`)

Run `python3 cardinality.py` with your own estimates and record:

- Baseline series for one metric: `<number>`
- Series if a `user_id` label is added: `<number>`
- The series count at which you would get nervous about a shared store: `<number>`

## Part F — The rule

Complete the sentence in your own words:

> Labels are for `<...>` and identifiers belong in `<...>` because `<...>`.
