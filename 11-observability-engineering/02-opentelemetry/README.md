# Module 11.2 — OpenTelemetry

> Before OpenTelemetry, every observability vendor had its own agent, SDK, and wire
> format — so instrumenting a service locked you into a backend. **OpenTelemetry
> (OTel)** is the vendor-neutral standard that broke that lock: instrument **once**,
> export **anywhere**. This module covers the OTel data model, how you instrument
> services, and the Collector — the routing hub every platform runs.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 11.1](../01-observability-fundamentals/), a kind cluster,
`kubectl`, and [Helm](https://helm.sh/). A Go toolchain is optional (the app sketch
is reference).

## Learning objectives

By the end of this module you will be able to:

- Describe the **OTel data model** — traces/spans, metrics, logs — and signal
  correlation via context.
- Choose between **auto-instrumentation** and **manual instrumentation**, and combine
  them.
- Explain the **Collector**'s receive → process → export pipeline and when to run it
  as an **agent** versus a **gateway**.
- Pick the right **processors** (batch, memory limiter, filter, attributes, sampling)
  and **exporters** (OTLP, Prometheus, Loki, Tempo).
- Contrast **head-based** and **tail-based** sampling and say where each belongs.

---

## 1. Concept

### The problem OTel solves

Observability used to mean picking a vendor and letting their proprietary agent and
SDK colonize your code. Want to switch backends, or send traces to one tool and
metrics to another? Re-instrument everything. OpenTelemetry — a CNCF project, the
merger of OpenTracing and OpenCensus — fixes this with three things:

- a **specification and data model** for traces, metrics, and logs,
- **SDKs** in every major language that implement it, and
- the **OTLP** wire protocol plus the **Collector** that speaks it.

The payoff: instrumentation is decoupled from the backend. Your code emits OTel; a
Collector routes it to Prometheus, Loki, Tempo, Jaeger, or a SaaS — swappable by
config, no code change. For a platform team, that is the difference between owning
your telemetry and renting it from a vendor.

### The data model: traces, metrics, logs

- **Trace** — the story of one request across services, a tree of **spans**.
- **Span** — one timed operation (an HTTP handler, a DB call). It has a name, start
  and end time, a **status**, key-value **attributes**, and **events**. Spans carry a
  `trace_id` (shared across the whole request) and a `span_id`, plus a parent link —
  that is what stitches the tree together.
- **Context propagation** — passing `trace_id`/`span_id` across process boundaries,
  usually in HTTP headers, so the next service's spans join the same trace
  (Module 11.5). This is the magic that makes a trace *distributed*.
- **Metric** — an aggregated measurement (counter, gauge, histogram) with a name and
  attributes (which become labels downstream).
- **Log** — a timestamped record that OTel can **correlate** with a trace by stamping
  it with the active `trace_id`. That shared ID is how you jump log → trace later.

**Semantic conventions** are the quiet hero: OTel standardizes *names*
(`http.request.method`, `http.response.status_code`, `service.name`) so telemetry is
comparable across every service and language. Enforcing these conventions is a
core platform job — consistency is what makes the data queryable at scale.

### Instrumenting a service: auto vs manual

- **Auto-instrumentation** — a language agent or library hooks well-known frameworks
  (HTTP servers, gRPC, DB drivers) and emits spans and metrics with **no code
  change**. In Java/Python/Node it is a drop-in agent; in Kubernetes the **OTel
  Operator** can inject it automatically. This is how you get every service to RED +
  traces "for free" — the golden-path move.
- **Manual instrumentation** — you call the SDK yourself to create spans around
  *business* operations the auto layer cannot see ("validate-cart", "charge-card")
  and add domain attributes (`order.value`, `tenant.id`). You almost always want
  **both**: auto for the plumbing, manual for the meaning.

```go
tracer := otel.Tracer("checkout")
ctx, span := tracer.Start(ctx, "charge-card")
defer span.End()
span.SetAttributes(attribute.String("tenant.id", tenantID))
```

### The Collector: receive, process, export

The **OTel Collector** is a standalone binary that receives telemetry, processes it,
and exports it — decoupling your apps from your backends. Its config is three kinds
of component wired into **pipelines**:

- **Receivers** — how data gets in (`otlp` over gRPC/HTTP, `prometheus` scrape,
  `filelog`, `hostmetrics`).
- **Processors** — what happens in between (see below). Order matters.
- **Exporters** — where data goes out (`otlp` to Tempo, `prometheus`, `loki`,
  `debug`).

You run the Collector in two complementary roles:

- **Agent** (a **DaemonSet**, one per node) — collects node-local signals
  (`hostmetrics`, container logs via `filelog`) and receives OTLP from pods on that
  node. Close to the source, cheap network hop.
- **Gateway** (a **Deployment**, a horizontally scaled pool) — agents forward to it;
  it does the expensive, cluster-wide work: **tail sampling**, batching, and fan-out
  to backends. Centralizing here means one place to change routing for everyone.

### Key processors

- **`memory_limiter`** — caps the Collector's own memory and sheds load before an
  OOM. Put it **first**; a Collector that crashes drops everyone's telemetry.
- **`batch`** — groups telemetry into fewer, larger exports. Essential for throughput;
  put it near the **end**.
- **`attributes` / `resource`** — add, redact, or rename attributes (stamp
  `cluster`, drop a PII field, enforce a semantic name).
- **`filter`** — drop data you do not want (health-check spans, a noisy metric).
- **`tail_sampling`** — decide whether to keep a trace **after** seeing all its spans
  (keep errors and slow traces, drop routine ones). Gateway-only, because it must see
  the whole trace.

### Head vs tail sampling

- **Head-based** — decide at the **start** of a request, before you know how it ends
  (e.g. keep 10% at random). Cheap and stateless, but it keeps boring requests and
  throws away rare errors just as often.
- **Tail-based** — buffer a trace's spans and decide at the **end**, when you know it
  errored or was slow. Keeps the *interesting* traces, but needs memory and all spans
  of a trace at one Collector — which is exactly why it lives in the **gateway**.

---

## 2. Why it matters for platform engineering

- **It is the anti-lock-in layer.** Instrument with OTel and you can change
  metrics/logs/traces backends by editing Collector config — no team re-instruments.
  That freedom is a strategic platform asset.
- **The Collector is a control point.** One place to enforce semantic conventions,
  redact PII, stamp tenant/cluster labels, cap cardinality, and route by tenant. You
  govern everyone's telemetry without touching their code.
- **Auto-instrumentation is a golden path.** The OTel Operator injecting agents means
  every service is traced by default. "Observable by default" becomes a platform
  guarantee, not a per-team chore.
- **Sampling is a cost lever you own.** Tail sampling at the gateway lets the platform
  keep trace bills sane while preserving the errors engineers actually need.

---

## 3. Mental model

Think of OTel as **standard pipes** between your code and your backends, with the
Collector as the junction box every team shares.

```text
  apps (OTel SDK: auto + manual)
        │  OTLP
        ▼
  ┌───────────────┐   one per node, close to the source
  │ AGENT          │   receivers: otlp, hostmetrics, filelog
  │ (DaemonSet)    │   light processing: memory_limiter, batch
  └──────┬────────┘
         │  OTLP (forward)
         ▼
  ┌───────────────┐   a scaled pool; the shared control point
  │ GATEWAY        │   tail_sampling, attributes (tenant/cluster),
  │ (Deployment)   │   filter, batch
  └──────┬────────┘
   ┌──────┼───────────┬───────────────┐
   ▼      ▼           ▼               ▼
 Tempo  Prometheus   Loki           (SaaS / Jaeger)
 traces  metrics     logs

  Change a backend? Re-wire an exporter here. The apps never notice.
```

Rule of thumb: **receivers are the "in," exporters are the "out," processors are the
"what happens in between," and the pipeline is the plumbing that connects them.**

---

## 4. Minimal implementation

The smallest useful Collector is one pipeline: receive OTLP, batch it, print it. This
single config proves the receive → process → export shape before any backend exists.

```yaml
# otel-collector-config.yaml — the smallest real pipeline
receivers:
  otlp:
    protocols:
      grpc: { endpoint: 0.0.0.0:4317 }
      http: { endpoint: 0.0.0.0:4318 }

processors:
  memory_limiter:
    check_interval: 1s
    limit_percentage: 80
    spike_limit_percentage: 25
  batch: {}

exporters:
  debug:
    verbosity: detailed

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [debug]
```

Run it and send one trace — no SDK or app required — using OTel's `telemetrygen`:

```bash
# run the Collector locally, then generate 5 spans into it
docker run --rm -p 4317:4317 -p 4318:4318 \
  -v "$PWD/otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml" \
  otel/opentelemetry-collector-contrib:0.110.0

telemetrygen traces --otlp-insecure --otlp-endpoint localhost:4317 --traces 5
```

You will see the spans printed by the `debug` exporter. Swap `debug` for an `otlp`
exporter pointing at Tempo and the exact same apps now feed a real trace store — the
whole point of OTel. The lab builds this into an agent + gateway topology on kind.

---

## 5. Hands-on lab

You will deploy the Collector twice on kind — as a **DaemonSet agent** and a
**Deployment gateway** — forward telemetry agent → gateway, generate traces and
metrics with `telemetrygen`, and watch them arrive at the gateway's debug exporter.

➡️ **[Start the lab: An OTel Collector agent + gateway on kind](./lab/README.md)**

---

## 6. Production considerations

- **Put `memory_limiter` first, `batch` last.** A Collector without a memory limiter
  OOMs under load and drops *everyone's* telemetry; without batching it melts your
  backends with tiny writes.
- **Run agent + gateway, not one giant Collector.** Agents stay cheap and node-local;
  the gateway scales horizontally and owns the stateful work (tail sampling). Size the
  gateway for peak trace volume and give it a PodDisruptionBudget.
- **Secure OTLP.** Enable TLS and auth between apps, agents, gateway, and backends;
  `--otlp-insecure` is for labs only. The Collector sees everyone's data — treat it
  like a privileged service.
- **Tail-sample at the gateway.** Head-sample lightly at the edge to shed obvious
  volume, then tail-sample centrally to keep errors and slow traces. Record the
  effective rate so counts can be scaled back up.
- **Govern attributes centrally.** Use `attributes`/`resource` processors to stamp
  `cluster`/`tenant`, drop PII, and enforce semantic conventions — so you do not rely
  on every team getting it right.
- **Version the config in Git.** Collector config is platform infrastructure. Review
  and roll it out like any other deployment (Phase 8), with a canary Collector.

## 7. Common mistakes

- **No `memory_limiter`.** — Under a telemetry spike the Collector OOMs and takes down
  the observability pipeline for every tenant. *Fix:* add `memory_limiter` first in
  every pipeline and set container limits to match.
- **Tail sampling on the agent.** — A per-node agent never sees all spans of a trace,
  so its sampling decisions are wrong. *Fix:* tail-sample only at the gateway, where a
  whole trace lands.
- **Auto-instrumentation only.** — You get HTTP/DB spans but none of the business
  operations that explain *why* something is slow. *Fix:* add manual spans around
  domain logic and attach domain attributes.
- **Ignoring semantic conventions.** — Each service invents `status`, `httpStatus`,
  `code`… and cross-service queries become impossible. *Fix:* adopt OTel semantic
  conventions and enforce them in the Collector.
- **Exporting raw, unbatched OTLP.** — Per-span network calls crush throughput and
  cost. *Fix:* always include a `batch` processor before exporters.
- **Treating the Collector as fire-and-forget.** — It silently drops data when
  queues fill or a backend is down. *Fix:* monitor the Collector's own metrics
  (`otelcol_exporter_send_failed_*`, queue size) — observe your observability.

## 8. Assessment

**Knowledge checks**

1. What problem does OpenTelemetry solve that per-vendor SDKs created?
2. What is a span, and what makes a set of spans a single distributed *trace*?
3. What are the three component types in a Collector pipeline, and in what order do
   `memory_limiter` and `batch` belong?
4. Why must tail-based sampling run on the gateway and not the per-node agent?
5. When would you add manual instrumentation on top of auto-instrumentation?

**Concept exercise**

> Explain to an app developer how they can switch their tracing backend from one tool
> to another **without changing a line of their application code** — and *why* that is
> possible. Do not name a specific vendor.

**Trade-off / debugging exercise**

> Traces are missing for about 1% of requests — and it is always the *errored* ones
> that are missing, which are exactly the ones you need. The team uses 1% head
> sampling. Explain why the errors disappear, and design a sampling strategy that
> keeps them while staying affordable at 50k req/s.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Per-vendor SDKs coupled instrumentation to a backend; switching meant
  re-instrumenting. OTel standardizes the data model and wire format so you
  instrument once and export anywhere.
- **Q2:** A span is one timed operation with a status and attributes. Spans share a
  `trace_id` and link to parents via `span_id`; propagating that context across
  service boundaries stitches them into one distributed trace.
- **Q3:** Receivers, processors, exporters. `memory_limiter` first (shed load before
  OOM), `batch` last (efficient export).
- **Q4:** Tail sampling must see *all* spans of a trace to judge it; a per-node agent
  only sees the spans that happened on its node, so it cannot make a correct
  whole-trace decision.
- **Q5:** When you need spans around business operations the auto layer cannot see, or
  domain attributes (tenant, order value) for slicing.
- **Debugging:** Head sampling decides at request start, before the error exists, so
  it drops 99% of everything — including 99% of errors — uniformly. Switch to tail
  sampling at the gateway: a policy that keeps 100% of traces with an error status or
  latency over a threshold, plus a small random percentage of the rest. You preserve
  all errors while sampling the boring majority.

</details>

---

## 9. Further reading

- OpenTelemetry — [Documentation](https://opentelemetry.io/docs/) and
  [What is OpenTelemetry?](https://opentelemetry.io/docs/what-is-opentelemetry/)
- OpenTelemetry — [Collector](https://opentelemetry.io/docs/collector/) and
  [Collector configuration](https://opentelemetry.io/docs/collector/configuration/)
- OpenTelemetry — [Sampling](https://opentelemetry.io/docs/concepts/sampling/)
- OpenTelemetry — [Operator and auto-instrumentation](https://opentelemetry.io/docs/kubernetes/operator/)
- OpenTelemetry — [Semantic conventions](https://opentelemetry.io/docs/specs/semconv/)
- CNCF — [OpenTelemetry project](https://www.cncf.io/projects/opentelemetry/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.1 — Observability Fundamentals](../01-observability-fundamentals/)
· _Next:_ [Module 11.3 — Metrics with Prometheus →](../03-metrics-with-prometheus/)
