# Module 11.5 — Distributed Tracing with Tempo

> Metrics say "error rate is up"; logs say "payment timed out"; only a **trace** says
> "the request spent 3 seconds waiting on the inventory service, which was blocked on
> a slow database call." **Tempo** is Grafana's trace store — cheap because, like
> Loki, it indexes very little. This module covers traces, context propagation, and
> how a `trace_id` stitches all three pillars together.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 11.2](../02-opentelemetry/),
[Module 11.4](../04-logging-with-loki/), and
[Docker Compose](https://docs.docker.com/compose/).

## Learning objectives

By the end of this module you will be able to:

- Explain a **trace**, a **span**, and how **context propagation** builds a distributed
  trace.
- Describe **W3C TraceContext** and B3 headers and why a standard matters.
- Outline Tempo's architecture and query traces with **TraceQL**.
- Correlate traces with logs and metrics using a shared `trace_id` and **exemplars**.
- Choose a sampling strategy that keeps the traces you actually need.

---

## 1. Concept

### Traces and spans

A **trace** is the complete record of one request as it travels through a system — a
tree of **spans**. Each **span** is a single timed operation with:

- a **name** (`POST /checkout`, `SELECT orders`),
- a **start and end time** (so you see duration),
- a **status** (ok / error),
- **attributes** (`http.route`, `db.system`, `tenant.id`), and
- identifiers: a **`trace_id`** shared by every span in the request, a unique
  **`span_id`**, and a **`parent_span_id`** linking a span to the one that caused it.

Those three IDs are what turn a pile of spans into a tree. Rendered on a timeline, a
trace is a **waterfall** that shows exactly where time went and where a failure began:

```text
trace a1b2c3…  (total 420ms)
├─ POST /checkout                                [████████████████████] 420ms  SERVER
│  ├─ validate-cart                              [██] 20ms
│  ├─ charge-card  → payments                    [        ██████████  ] 300ms  CLIENT
│  │   └─ SELECT ledger                          [          ████████  ] 260ms  ← the cost
│  └─ reserve-stock → inventory                  [                 ██ ] 60ms
```

### Context propagation: how a trace becomes distributed

The hard part of *distributed* tracing is that each service is a separate process.
When `checkout` calls `payments` over HTTP, `payments` must know it is part of the
same trace and who its parent span is. That is **context propagation**: the caller
injects the trace context into the outgoing request (HTTP headers), and the callee
extracts it and continues the same trace.

The standard is **W3C TraceContext**, carried in two headers:

- **`traceparent`** — version, `trace_id`, parent `span_id`, and trace flags
  (including whether it was sampled), e.g.
  `00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01`.
- **`tracestate`** — optional vendor-specific key-values.

**B3** (single or multi-header, from Zipkin) is the older propagation format you will
still meet. The point of a standard is interoperability: as long as every service and
proxy speaks the same propagation format, a trace flows unbroken across languages,
frameworks, and service-mesh hops. OpenTelemetry (Module 11.2) handles inject/extract
for you — your job as a platform is to make sure **every** hop propagates it, including
gateways and meshes.

### Tempo architecture

Tempo makes the same bet Loki does: **do not index the payload**. It stores whole
traces in cheap object storage keyed by `trace_id`, with only a lightweight index.
That makes ingesting 100% of spans affordable. Its components mirror Loki's:

- **Distributor** — receives spans (OTLP, Jaeger, Zipkin) and routes them by
  `trace_id`.
- **Ingester** — batches spans into blocks and flushes them to object storage.
- **Querier** — fetches and assembles traces for queries.
- **Compactor** — merges blocks and enforces retention.
- **Metrics-generator** (optional) — derives **span metrics** (RED from spans) and
  **service-graph** metrics, and writes them to Prometheus/Mimir.

Backends are S3, GCS, Azure, or local filesystem for a lab. In the LGTM stack, the
**T** is Tempo.

### TraceQL

**TraceQL** queries traces by their spans' attributes:

```text
{ resource.service.name = "checkout" }          all traces touching checkout
{ duration > 500ms }                             slow traces
{ status = error }                               failed traces
{ resource.service.name = "checkout" && span.http.status_code >= 500 }
```

You select spans with `{ ... }` and Tempo returns the traces that contain matching
spans. This is how you find "the slow, errored checkout traces from the last hour"
without knowing a `trace_id` in advance.

### Correlation: the real payoff

A trace is most powerful when it is a **hub** linking the other pillars:

- **Logs ↔ traces.** If every log line carries a `trace_id` (Module 11.4), you can
  jump from an error log straight to its trace — and from a slow span to its logs.
  Grafana wires this with a derived field (log → trace) and trace-to-logs (trace →
  log).
- **Metrics ↔ traces: exemplars.** An **exemplar** is a specific trace `trace_id`
  attached to a metric sample — "this one point in the p99 latency histogram came
  from *this* trace." Click the spike on the latency graph and land on an actual slow
  trace. Exemplars are the bridge from an aggregate metric to a concrete example.

This metric → log → trace path is the whole reason you collect all three. It is the
difference between "something is wrong" and "here is the exact request that failed and
why."

### Sampling

You usually cannot store every trace at scale (Module 11.1), so you sample:

- **Head-based** — decide at the start (e.g. keep 10%). Cheap and stateless, but it
  discards rare errors as readily as routine successes.
- **Tail-based** — buffer a trace's spans and decide at the end, keeping errors and
  slow traces. More useful, needs memory and a view of the whole trace — which is why
  it runs in the OTel **gateway** (Module 11.2), not per node.

Tempo's cheap storage means some teams ingest 100% and rely on retention plus TraceQL
rather than aggressive sampling — a cost trade-off you decide per environment.

---

## 2. Why it matters for platform engineering

- **Tracing is how you debug a system you did not write.** In a microservice platform,
  a user-facing failure crosses many teams' services. A trace localizes the fault to
  one hop in seconds — without it, you are guessing across a dozen dashboards.
- **Propagation is a platform guarantee.** A single service that drops the
  `traceparent` header breaks every trace that passes through it. The platform must
  ensure the gateway, mesh, and service template all propagate context — teams should
  get it for free.
- **Correlation is the platform's force multiplier.** Wiring metrics → logs → traces
  once, centrally, means every engineer can pivot between pillars without configuring
  anything. That is a huge reduction in cognitive load.
- **Cheap tracing changes the economics.** Choosing Tempo (index-light) over a
  heavyweight tracing store lets a platform keep far more traces for the same spend —
  more forensic coverage when it matters.

---

## 3. Mental model

A trace is a **story with a shared ID**; spans are its chapters; the `trace_id` is the
ISBN that lets every other system point at the same book.

```text
   one request  ───────────────────────────────────────────────▶ time
   trace_id = a1b2c3  (every span carries it; parent/child links build the tree)

        metrics                 logs                    traces (Tempo)
   "p99 latency ↑"   ─────▶  "pay timeout            ─────▶  span waterfall:
     exemplar: a1b2c3         trace_id=a1b2c3"                 payments → ledger
          │                        │                              ▲
          └──────────── same trace_id is the join key ───────────┘

   Collect all three so you can walk: alert → exact log → exact trace → root cause.
```

Rule of thumb: **metrics find the *when*, logs tell you the *what*, traces show you
the *where* — and `trace_id` is the thread connecting them.**

---

## 4. Minimal implementation

A trace is just structured data you can emit over OTLP. The smallest meaningful trace
is a parent span and one child, sharing a `trace_id`, linked by `parent_span_id`:

```json
{
  "resourceSpans": [{
    "resource": { "attributes": [
      { "key": "service.name", "value": { "stringValue": "checkout" } } ] },
    "scopeSpans": [{ "spans": [
      { "traceId": "a1b2c3d4e5f60718293a4b5c6d7e8f90",
        "spanId": "1111111111111111", "name": "POST /checkout",
        "kind": 2, "startTimeUnixNano": "1", "endTimeUnixNano": "420000000",
        "status": { "code": 2 } },
      { "traceId": "a1b2c3d4e5f60718293a4b5c6d7e8f90",
        "spanId": "2222222222222222", "parentSpanId": "1111111111111111",
        "name": "charge-card", "kind": 3,
        "startTimeUnixNano": "60000000", "endTimeUnixNano": "360000000" }
    ]}]
  }]
}
```

Post it to any OTLP endpoint and the trace is stored and queryable — no SDK required
(`trace_id`/`span_id` are hex strings in OTLP/JSON):

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H 'Content-Type: application/json' -d @trace.json
```

That is exactly what the lab's generator does in a loop — and it writes a matching log
line carrying the same `trace_id`, so you can jump log → trace for real.

---

## 5. Hands-on lab

You will run Tempo, Loki, Grafana, and a generator that emits **correlated** traces
and logs (same `trace_id`), then query traces with TraceQL and pivot from an error log
straight to its trace in Grafana.

➡️ **[Start the lab: TraceQL and log↔trace correlation](./lab/README.md)**

---

## 6. Production considerations

- **Propagate context everywhere, or traces break.** Audit that gateways, service
  meshes, and every service template inject/extract W3C TraceContext. One non-
  propagating hop severs every trace through it. Prefer auto-instrumentation to make
  it the default.
- **Decide sampling per environment.** Aggressive head sampling in high-volume
  production; little or none in staging. Where you need errors, tail-sample at the
  gateway so you keep them. Record the effective rate.
- **Right-size storage and retention.** Tempo is cheap, but 100% ingest at scale still
  costs. Set block retention and back it with object storage; keep enough history to
  investigate yesterday's incident.
- **Make correlation a default.** Provision the trace↔log and metric→trace
  (exemplar) links in Grafana centrally so every team can pivot without setup. Mandate
  a `trace_id` field in the logging library.
- **Protect PII in spans.** Span attributes can leak secrets or personal data. Use the
  Collector's `attributes`/`redaction` processors to scrub before export.
- **Watch the tracing pipeline itself.** Dropped spans (Collector queue full, Tempo
  ingester pressure) silently lose data. Monitor Tempo and Collector metrics.

## 7. Common mistakes

- **A hop that doesn't propagate context.** — A service or proxy drops
  `traceparent`, so traces fragment into disconnected pieces. *Fix:* standardize on
  W3C TraceContext and verify propagation through gateways and meshes.
- **Head-sampling away your errors.** — 1% head sampling keeps 1% of errors, exactly
  the ones you need. *Fix:* tail-sample at the gateway to keep all errors and slow
  traces.
- **No `trace_id` in logs.** — You cannot pivot from a log to its trace, losing half
  the value of running both. *Fix:* inject `trace_id` into every structured log line.
- **Indexing traces like a search engine.** — Expecting full-text search over span
  contents misunderstands Tempo. *Fix:* query with TraceQL on attributes; add the
  attributes you will search for at instrumentation time.
- **Unbounded span attributes.** — Huge or high-cardinality attributes bloat storage
  and can carry PII. *Fix:* attach bounded, useful attributes; redact sensitive ones.
- **Treating traces as the only signal.** — Traces are sampled and per-request; they
  do not replace aggregate metrics or full logs. *Fix:* use all three, correlated.

## 8. Assessment

**Knowledge checks**

1. What three identifiers turn a set of spans into a single trace tree?
2. What is context propagation, and which headers does W3C TraceContext use?
3. Why can Tempo afford to ingest far more traces than a full-text tracing store?
4. What is an exemplar, and which two pillars does it connect?
5. Why does tail-based sampling preserve errors that head-based sampling loses?

**Concept exercise**

> Explain how you would find *which* downstream service made one specific user request
> slow **without using the words "trace," "span," or "Tempo."** Describe the data you
> would need to record per request and how you would reconstruct the timeline.

**Trade-off / debugging exercise**

> A request fails for a user. You have the error log (with a `trace_id`), full metrics,
> and 100%-ingested traces. Describe the exact pivot sequence you would use across the
> three pillars to reach root cause — and explain what you would be unable to do if the
> team had used 1% head sampling instead.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** `trace_id` (shared by all spans), `span_id` (unique per span), and
  `parent_span_id` (links a span to its cause).
- **Q2:** Injecting trace context into outgoing requests and extracting it in the
  callee so both share one trace. W3C TraceContext uses `traceparent` (and optional
  `tracestate`).
- **Q3:** It indexes only a little and stores whole traces by `trace_id` in cheap
  object storage, rather than indexing every span's contents.
- **Q4:** An exemplar is a specific `trace_id` attached to a metric sample; it links
  **metrics** to **traces** (click a point on a graph, jump to the example trace).
- **Q5:** Head sampling decides before the outcome is known and drops most traces
  uniformly, including errors. Tail sampling decides after seeing the whole trace, so
  it can keep every errored or slow trace.
- **Debugging:** Start at the error log, copy its `trace_id`, open that exact trace,
  read the waterfall to the failing/slow span, and inspect its attributes and child
  spans for the root cause; use metrics to see blast radius and timing. With 1% head
  sampling, the failed request's trace would almost certainly not exist, so the log's
  `trace_id` would resolve to nothing — you could see *that* it failed but not *where*.

</details>

---

## 9. Further reading

- Grafana — [Tempo documentation](https://grafana.com/docs/tempo/latest/) and
  [TraceQL](https://grafana.com/docs/tempo/latest/traceql/)
- W3C — [Trace Context specification](https://www.w3.org/TR/trace-context/)
- OpenTelemetry — [Context propagation](https://opentelemetry.io/docs/concepts/context-propagation/)
  and [traces](https://opentelemetry.io/docs/concepts/signals/traces/)
- Grafana — [Exemplars](https://grafana.com/docs/grafana/latest/fundamentals/exemplars/)
- Grafana — [Tempo metrics-generator](https://grafana.com/docs/tempo/latest/metrics-generator/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.4 — Logging with Loki](../04-logging-with-loki/)
· _Next:_ [Module 11.6 — Grafana Dashboards →](../06-grafana-dashboards/)
