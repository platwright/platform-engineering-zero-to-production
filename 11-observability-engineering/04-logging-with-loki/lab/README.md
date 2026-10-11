# Lab — LogQL over structured logs

> You will run Loki, Promtail, Grafana, and a JSON log generator with Docker Compose,
> then use **LogQL** in Grafana Explore to filter logs, parse structured fields, and
> compute an error rate *from log lines* — all while keeping labels low-cardinality.
> Fully local and free.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A running Loki stack and a set of LogQL queries that filter by label,
parse JSON, filter by a parsed field, and graph an error rate.

## Objectives

- Ship structured logs into Loki with a small, bounded label set.
- Write LogQL log queries and metric queries.
- Prove that identifiers stay in the line (parsed at query time), not in labels.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker and [Docker Compose](https://docs.docker.com/compose/).
- [Module 11.4](../README.md) theory.
- Starter files in this folder: [`docker-compose.yaml`](./docker-compose.yaml),
  [`log-generator.py`](./log-generator.py),
  [`promtail-config.yaml`](./promtail-config.yaml),
  [`grafana-datasource.yaml`](./grafana-datasource.yaml), and
  [`queries.logql`](./queries.logql).

## Steps

1. **Start the stack.** From this folder:

   ```bash
   docker compose up -d
   docker compose ps
   ```

   You get Loki (`:3100`), Promtail (tailing the generator's log file), Grafana
   (`:3000`, anonymous admin), and a `log-generator` writing JSON lines — a mix of
   `info`/`warn`/`error` for the `checkout` service.

2. **Open Grafana Explore.** Browse to
   [http://localhost:3000/explore](http://localhost:3000/explore). The Loki data
   source is pre-provisioned. Set the time range to **Last 15 minutes**.

3. **Select a stream by label.** Run the simplest query and confirm logs flow:

   ```logql
   {service="checkout"}
   ```

   The only labels are `service`, `job`, and `level` — a deliberately tiny set. Open a
   line and notice the rich detail (`route`, `status`, `trace_id`) lives *inside* the
   JSON, not in labels.

4. **Filter error lines two ways.** A cheap line filter, then a structured parse:

   ```logql
   {service="checkout"} |= "error"
   {service="checkout"} | json | level="error"
   ```

   Both find errors; the `| json` form is precise because it matches the parsed
   `level` field rather than any line containing the word "error".

5. **Filter by a parsed field that is NOT a label.** `status` only exists inside the
   JSON, yet you can still query it:

   ```logql
   {service="checkout"} | json | status >= 500
   ```

   This is the whole point: high-cardinality detail stays in the line and is parsed at
   query time, so it never costs you a stream.

6. **Reshape output.** Show just the message, dropping the JSON noise:

   ```logql
   {service="checkout"} | json | level="error" | line_format "{{.msg}}"
   ```

7. **Compute a metric from logs.** Switch the visualization to a graph and run:

   ```logql
   sum(rate({service="checkout"} | json | level="error" [5m]))
   sum by (level) (count_over_time({service="checkout"} | json [5m]))
   ```

   You just turned log lines into an alertable time series — the same shape as a
   Prometheus query, which is why Loki fits the LGTM stack so cleanly.

8. **Prove the cardinality guardrail.** Open
   [`promtail-config.yaml`](./promtail-config.yaml). Only `level` is promoted to a
   label; `trace_id`, `route`, and `status` are intentionally left in the line. Adding
   `trace_id` to the `labels` stage would create a new stream per request — the
   mistake from the lesson.

## Expected result

In Grafana Explore, `{service="checkout"}` streams live logs; `| json | status >= 500`
returns only server-error lines parsed from JSON; and
`sum(rate({service="checkout"} | json | level="error" [5m]))` draws a non-zero error
line graph. The stream set stays tiny (a handful of `service`/`level` combinations)
no matter how many distinct `trace_id`s appear.

## Cleanup

> Always tear the stack down, including the volume. Never skip this.

```bash
docker compose down -v
```

## Reflection

- `status` and `trace_id` were queryable without being labels. What would have gone
  wrong if you had made `trace_id` a label instead?
- Your error-rate query produced a time series from text logs. When would you alert on
  a log-derived metric versus a Prometheus metric for the same condition?
- The logs already contain `trace_id`. How does that single field set up the
  correlation you will build in [Module 11.5](../../05-distributed-tracing-with-tempo/)?

## Stretch goals (optional)

- Add a second service to [`log-generator.py`](./log-generator.py) and compare error
  rates with `sum by (service) (rate(... [5m]))`.
- Use `| json | latency_ms > 200` to find slow requests, then
  `quantile_over_time(0.99, ... | unwrap latency_ms [5m])` to approximate p99 latency
  from logs — and note why Prometheus histograms are still the better tool for that.
- Point Grafana at a Prometheus too (from Module 11.3) and put a logs panel and a
  metrics panel side by side — a preview of Module 11.6.
