# Lab — TraceQL and log↔trace correlation

> You will run Tempo, Loki, Grafana, and a generator that emits **correlated** traces
> and logs (a shared `trace_id`), then search traces with **TraceQL**, read a span
> waterfall, and pivot from an error log straight to its trace. Fully local and free.

**Estimated time:** ~50–65 minutes
**Type:** Build
**Deliverable:** TraceQL queries that find slow and errored traces, and a working
log → trace jump in Grafana using a shared `trace_id`.

## Objectives

- Store and query traces in Tempo with TraceQL.
- Read a span waterfall to localize where time and failures occur.
- Correlate pillars: jump from a log line to its trace by `trace_id`.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker and [Docker Compose](https://docs.docker.com/compose/).
- [Module 11.5](../README.md) theory (and [11.4](../../04-logging-with-loki/) for
  Loki/LogQL).
- Starter files in this folder: [`docker-compose.yaml`](./docker-compose.yaml),
  [`tempo-config.yaml`](./tempo-config.yaml),
  [`trace-log-generator.py`](./trace-log-generator.py),
  [`promtail-config.yaml`](./promtail-config.yaml),
  [`grafana-datasources.yaml`](./grafana-datasources.yaml), and
  [`queries.traceql`](./queries.traceql).

## Steps

1. **Start the stack.** From this folder:

   ```bash
   docker compose up -d
   docker compose ps
   ```

   This runs Tempo (traces), Loki + Promtail (logs), Grafana (pre-provisioned with
   both data sources and the trace↔log links), and a generator that every second
   sends a 3-span trace to Tempo **and** writes a matching log line carrying the same
   `trace_id`. Some traces are marked errored and slow on purpose.

2. **Search traces with TraceQL.** Open
   [http://localhost:3000/explore](http://localhost:3000/explore), pick the **Tempo**
   data source, and switch the query type to **TraceQL**. Set the range to **Last 15
   minutes** and run:

   ```text
   { resource.service.name = "checkout" }
   ```

   You get a list of recent traces. Click one and read the **waterfall**: a
   `POST /checkout` SERVER span with `charge-card` → `payments` and a `SELECT ledger`
   child — exactly where the time goes.

3. **Find the problems.** Narrow to slow and failed traces:

   ```text
   { duration > 300ms }
   { status = error }
   { resource.service.name = "checkout" && span.http.status_code >= 500 }
   ```

   Open an errored trace and confirm the failing span is flagged red with its status.

4. **Look at the correlated logs.** Switch the data source to **Loki** and run:

   ```logql
   {service="checkout"} | json | level="error"
   ```

   Each error line contains a `trace_id` field — the same IDs Tempo stored.

5. **Pivot log → trace.** Expand an error log line. Grafana shows a **derived field**
   link labelled `TraceID` (configured in
   [`grafana-datasources.yaml`](./grafana-datasources.yaml)). Click it: Grafana opens
   the **exact trace** for that log line in Tempo. That jump — alert/log to the precise
   failing request — is the entire payoff of the three pillars.

6. **Pivot trace → logs.** From a trace in Tempo, use **Logs for this span** (the
   `tracesToLogsV2` link). Grafana queries Loki filtered to that `trace_id`, showing
   the log lines emitted during the request.

7. **Reason about exemplars (concept).** You linked logs and traces by a shared ID.
   A metric **exemplar** does the same from a graph: a `trace_id` attached to a
   latency sample lets you click a spike and land on the slow trace. You will see the
   metrics side of this in [Module 11.6](../../06-grafana-dashboards/).

## Expected result

TraceQL returns recent `checkout` traces; `{ status = error }` and
`{ duration > 300ms }` filter to the failed and slow ones; and expanding an error log
in Loki reveals a `TraceID` link that opens the matching trace in Tempo. Logs and
traces share the same `trace_id`, so the pivot resolves to real data in both
directions.

## Cleanup

> Always tear the stack down, including volumes. Never skip this.

```bash
docker compose down -v
```

## Reflection

- The log → trace jump only worked because both carried the same `trace_id`. What
  single piece of discipline, applied to every service, makes this possible platform-
  wide?
- You ingested 100% of traces here. At 50k requests/second, what would you change, and
  which traces would you be most careful to keep?
- Tempo indexes almost nothing yet TraceQL still found errored and slow traces. What
  did it search over, and why is that cheaper than full-text indexing?

## Stretch goals (optional)

- Edit [`trace-log-generator.py`](./trace-log-generator.py) to add a fourth span
  (e.g. `reserve-stock` → `inventory`) and confirm it appears in the waterfall.
- Raise the error rate in the generator and watch `{ status = error }` return more
  traces; correlate the count with the Loki error-rate query from Module 11.4.
- Add the Tempo **metrics-generator** (service-graph / span metrics) to
  [`tempo-config.yaml`](./tempo-config.yaml) and reason about how that would feed RED
  metrics into Prometheus without instrumenting the app.
