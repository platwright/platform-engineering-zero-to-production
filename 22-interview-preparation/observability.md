# Interview Prep — Observability

> This domain tests whether you can turn signals into decisions: pick the right
> telemetry, define SLOs users feel, and alert on symptoms without drowning in
> noise. Interviewers probe the three pillars, OpenTelemetry, cardinality, and
> burn-rate alerting. Practice explaining each mechanism — and the trade-offs —
> out loud before reading the model answer.

## The three pillars

### Q: What is the difference between metrics, logs, and traces?

**What they're really asking:** Do you know what each signal is good for, and that they are complementary?

- **Metrics** — numeric time series, cheap and aggregatable, low cardinality. Best for dashboards, trends, and alerts: *is something wrong?*
- **Logs** — discrete timestamped events with detail. Best for forensics: *what exactly happened?*
- **Traces** — the path of a single request across services as timed spans. Best for latency and distributed flow: *where is the time going?*

They work together: a metric alert fires, a trace localizes the slow service, logs explain the detail. Exemplars link a metric spike directly to an example trace.

**Going deeper:** [11.1 · Observability Fundamentals](../11-observability-engineering/01-observability-fundamentals/)

**Red flags:** "Just log everything." Treating logs as the answer to every question ignores cost and queryability.

### Q: What is observability, and how is it different from monitoring?

**What they're really asking:** Do you understand known-unknowns versus unknown-unknowns?

**Monitoring** watches for *known* failure modes with predefined dashboards and
alerts. **Observability** is the property that you can ask *new* questions of your
system from its outputs — without shipping new code — to debug problems you did not
anticipate. Rich, high-cardinality, structured telemetry is what makes that
exploration possible. Monitoring is a subset of an observable system.

**Going deeper:** [11.1 · Observability Fundamentals](../11-observability-engineering/01-observability-fundamentals/)

### Q: What is OpenTelemetry and why does it matter?

**What they're really asking:** Do you understand vendor-neutral instrumentation and the Collector?

OpenTelemetry (OTel) is the CNCF standard — APIs, SDKs, and a Collector — for
generating and exporting traces, metrics, and logs with a shared data model, semantic
conventions, and context propagation. It matters because you **instrument once and
export anywhere**, avoiding vendor lock-in. The **Collector** sits between apps and
backends to receive, batch, process, sample, and route telemetry, so changing your
backend never means re-instrumenting your services.

**Going deeper:** [11.2 · OpenTelemetry](../11-observability-engineering/02-opentelemetry/)

**Red flags:** Hard-wiring a single vendor's agent into every service with no abstraction layer.

### Q: What is cardinality, and why does it wreck metrics systems?

**What they're really asking:** Do you know the number-one way to blow up Prometheus?

Cardinality is the number of unique time series, which is the product of all label
value combinations. A high-cardinality label — user ID, request ID, full URL —
multiplies series into the millions, exhausting Prometheus memory and storage and
slowing queries. Keep metric labels **bounded and low-cardinality**; put
high-cardinality identifiers in **logs and traces**, not metric labels.

**Going deeper:** [11.3 · Metrics with Prometheus](../11-observability-engineering/03-metrics-with-prometheus/)

**Red flags:** Putting user IDs or request IDs in Prometheus labels.

## SLOs and alerting

### Q: What is an SLI, an SLO, and an SLA?

**What they're really asking:** Can you separate the measurement, the target, and the contract?

- **SLI** — a measured indicator of health, expressed as good events over valid events (for example, the fraction of requests served under 300 ms and without a 5xx).
- **SLO** — your internal target for that SLI over a window (99.9% good over 28 days). The SLO defines the **error budget** = 1 − SLO.
- **SLA** — an external contract with consequences (credits) if breached; usually set looser than the SLO so you have headroom.

**Going deeper:** [11.7 · SLOs and Error Budgets](../11-observability-engineering/07-slos-and-error-budgets/)

### Q: How do you choose a good SLI?

**What they're really asking:** Do you measure what users feel, not internal causes?

A good SLI reflects the **user's experience** — availability, latency, correctness, or
freshness — measured as close to the user as practical and framed as good over valid
events. CPU and memory are **causes**, not SLIs; a service can be at 90% CPU and
perfectly healthy from the user's view. Pick the few signals that, if broken, mean
the user is unhappy.

**Going deeper:** [11.7 · SLOs and Error Budgets](../11-observability-engineering/07-slos-and-error-budgets/)

**Red flags:** Making CPU utilization an SLO, or defining dozens of SLIs nobody acts on.

### Q: What is error budget burn rate, and how do multi-window multi-burn-rate alerts work?

**What they're really asking:** Do you understand the Google SRE alerting model?

**Burn rate** is how fast you are spending the error budget relative to the rate that
would exhaust it exactly at the window's end:

```text
burn rate = (observed error ratio) / (1 - SLO)

burn rate 1    → budget runs out exactly at window end
burn rate 14.4 → a 30-day budget is gone in ~2 days
```

A single threshold either pages too late (slow) or flaps (noisy). The SRE fix is
**multi-window, multi-burn-rate**: require a high burn rate confirmed over both a
**long and a short window** before paging, so a transient spike does not wake anyone,
but a genuine fast burn does. Lower burn rates over longer windows become tickets,
not pages.

- Page: burn rate ~14.4 over 1h and 5m (about 2% of budget in an hour) — fast burn.
- Ticket: burn rate ~6 over 6h, or lower — sustained but slower.

**Going deeper:** [11.7 · SLOs and Error Budgets](../11-observability-engineering/07-slos-and-error-budgets/)

### Q: How do you design alerts that are actionable and not noisy?

**What they're really asking:** Have you fought alert fatigue with symptom-based alerting?

- Alert on **symptoms** (SLO burn, user-facing errors/latency), not **causes** (a single node's CPU).
- Every alert should be **urgent, actionable, and tied to a runbook**; if there is nothing to do, it should not page.
- **Page** only on fast, user-impacting burn; route slow burns and non-urgent issues to tickets.
- Use **multi-window burn-rate** alerting for precision and recall, and delete alerts that never lead to action.

**Going deeper:** [11.7 · SLOs and Error Budgets](../11-observability-engineering/07-slos-and-error-budgets/) and [11.8 · Platform Observability Strategy](../11-observability-engineering/08-platform-observability-strategy/)

**Red flags:** Paging on static thresholds like "CPU > 80%," or alerts with no runbook.

## Tracing and strategy

### Q: Head sampling versus tail sampling — which and why?

**What they're really asking:** Do you know how to keep the interesting traces at lower cost?

**Head sampling** decides at the *start* of a trace (for example, keep 10% at random)
— cheap and simple, but it will throw away the rare error and slow traces you most
want. **Tail sampling** buffers complete traces and decides *after* seeing the whole
thing, so you keep all errors and slow outliers while sampling the boring fast
successes. Tail sampling costs more resources (the Collector must hold traces) but
retains the signal that matters.

**Going deeper:** [11.5 · Distributed Tracing with Tempo](../11-observability-engineering/05-distributed-tracing-with-tempo/) and [11.2 · OpenTelemetry](../11-observability-engineering/02-opentelemetry/)

### Q: What are the RED and USE methods?

**What they're really asking:** Do you have a framework for what to measure?

- **RED** — for request-driven **services**: **R**ate, **E**rrors, **D**uration.
- **USE** — for **resources**: **U**tilization, **S**aturation, **E**rrors (CPU, memory, disk, queues).

Use RED for your services and USE for the infrastructure they run on; together they
cover the golden signals.

**Going deeper:** [11.1 · Observability Fundamentals](../11-observability-engineering/01-observability-fundamentals/) and [11.6 · Grafana Dashboards](../11-observability-engineering/06-grafana-dashboards/)

### Q: How do you approach observability as a platform capability?

**What they're really asking:** Do you make observability a paved road, not a per-team project?

Ship observability as a golden path: **OTel instrumentation defaults**, pre-wired
metrics/logs/traces, standard dashboards and **SLO templates**, and multi-tenant
backends (Prometheus/Mimir, Loki, Tempo, Grafana) so teams get the golden signals for
free. Then actively manage **cost and cardinality** through retention, sampling, and
label hygiene, and make ownership clear. The goal is that a new service is observable
by default without its team building a stack.

**Going deeper:** [11.8 · Platform Observability Strategy](../11-observability-engineering/08-platform-observability-strategy/)

**Red flags:** Every team running its own Prometheus with no standards, no cost control, and no shared SLO tooling.
