# Module 11.1 — Observability Fundamentals

> Monitoring tells you *that* something is wrong. Observability lets you ask *why* —
> including for failures you never predicted. This module defines observability from
> first principles, introduces the three pillars and the signal frameworks (RED,
> USE, the four golden signals), and names the two costs — **cardinality** and
> **sampling** — that shape every decision you will make for the rest of the phase.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 3](../../03-kubernetes-fundamentals/) concepts and Python 3
for a tiny experiment. No cloud, no cluster.

## Learning objectives

By the end of this module you will be able to:

- Distinguish **monitoring** from **observability** and explain why platform scale
  forces the shift.
- Describe the **three pillars** — metrics, logs, traces — and pick the right one
  for a question.
- Apply **RED**, **USE**, and the **four golden signals** to services and resources.
- Explain **cardinality** and **sampling**, and why they cap what you can afford to
  collect.
- Name the signal a platform owes its tenants versus the signals each app team owns.

---

## 1. Concept

### Observability borrowed from control theory

The word comes from control theory: a system is **observable** if you can infer its
complete internal state purely from its external outputs. Transplanted to software:
a system is observable when its *outputs* — the telemetry it emits — let you
reconstruct what is happening *inside* it, without shipping new code to answer each
new question.

That last clause is the whole game. If answering "why are checkout requests slow for
users in Germany on the new app version?" requires you to add a log line and redeploy,
your system was not observable with respect to that question. If the data was already
there and you just had to query it, it was.

### Monitoring vs observability

These are related but not the same, and conflating them is the most common
conceptual error in this field.

- **Monitoring** is collecting and alerting on **predefined** signals. You decide in
  advance what matters — CPU, error rate, a health check — build a dashboard and an
  alert, and watch it. Monitoring answers **known questions**: "Is the thing I
  expected to break, broken?"
- **Observability** is a **property of the system**: how well its telemetry lets you
  explore **unknown** questions after the fact. Observability answers **novel
  questions**: "This symptom is new and I did not predict it — can I still get to the
  cause from the data I already have?"

Monitoring is a *subset* of what observability enables. You still build dashboards
and alerts — but on top of rich, high-dimensional telemetry you can slice and dice,
rather than a handful of pre-aggregated numbers. The shift matters because at
platform scale you operate **hundreds of services you did not write**. You cannot
predict their failure modes, so you cannot pre-build every dashboard. You need the
ability to ask new questions.

### The three pillars

Observability telemetry comes in three complementary shapes. None is sufficient
alone; the power is in correlating them.

- **Metrics** — numeric measurements aggregated over time (a request counter, a CPU
  gauge, a latency histogram). Cheap to store and fast to query because they are
  just numbers over time. Great for **trends, dashboards, and alerts**; poor at
  explaining a *single* weird request because the detail was aggregated away.
- **Logs** — timestamped records of discrete events, ideally **structured**
  (key-value / JSON) rather than free text. Great for the **detail of what happened**
  in one event; expensive at volume and hard to aggregate if unstructured.
- **Traces** — the end-to-end journey of **one request** across many services,
  broken into timed **spans**. Great at answering **"where did the time go and where
  did it fail"** across a distributed call graph; they need context propagation and
  are usually **sampled**.

```text
Question                                   Reach for…
──────────────────────────────────────    ──────────
"Is error rate rising across the fleet?"   Metrics  (aggregate, trend, alert)
"What exactly happened in request X?"      Logs     (the event detail)
"Which of 9 services made X slow?"         Traces   (the span waterfall)
```

### Frameworks: RED, USE, and the four golden signals

You do not instrument randomly. Three battle-tested frameworks tell you *which*
signals to collect first.

- **RED** (for **request-driven services**): **R**ate (requests/sec), **E**rrors
  (failed requests/sec), **D**uration (latency distribution). If you measure only
  three things about a service, measure these.
- **USE** (for **resources** — nodes, disks, queues): **U**tilization (how busy),
  **S**aturation (how much queued/overcommitted work is waiting), **E**rrors
  (device/driver errors). RED watches the work; USE watches the machine doing it.
- **The four golden signals** (Google SRE, for **any user-facing system**):
  **Latency**, **Traffic**, **Errors**, **Saturation**. A superset-flavored blend of
  RED and USE; the canonical "if you can only build one dashboard" list.

A subtle but critical point about **latency**: always separate the latency of
**successful** requests from **failed** ones, and report **percentiles**
(p50/p95/p99), never just an average. A fast error and a slow success both lie to a
mean. Tail latency is where users actually feel pain.

### The two costs: cardinality and sampling

Every design choice in this phase is a trade against two costs.

**Cardinality** is the number of unique time series a metric produces — one series
per unique combination of label values. It multiplies:

```text
http_requests_total{method, status, path, pod}

 methods(4) × statuses(5) × paths(200) × pods(50) = 200,000 series
                                                     for ONE metric name
```

Add a high-cardinality label like `user_id` or a raw URL with IDs in it, and series
count explodes into the millions. Memory, storage, and query cost scale with series
count, so **high-cardinality labels are the number-one way to melt a metrics
backend**. The fix is discipline: labels are for *bounded, low-cardinality*
dimensions (method, status, route **template**), never unbounded identifiers.

**Sampling** is the answer to a different scale problem: you cannot afford to store a
trace for **every** request at high throughput. So you keep a representative subset —
a fixed percentage (**head sampling**) or a smart selection that keeps all the errors
and slow ones (**tail sampling**, Module 11.2). Sampling trades completeness for
affordability; the art is keeping the *interesting* requests.

---

## 2. Why it matters for platform engineering

- **You are on the hook for systems you did not write.** A platform runs other
  teams' code. When something breaks at 2am, "add a log line and redeploy" is not
  available to you — the service is not yours. Observability is the only way you can
  debug a black box you operate but did not author.
- **Signals are a platform product, not an afterthought.** "Every service gets RED
  metrics, structured logs, and traces, pre-wired, for free" is a golden path — one
  of the most valuable things a platform offers. You are selling *insight as a
  default*, not asking each team to reinvent it.
- **Cardinality is a multi-tenant blast radius.** One team's careless `user_id`
  label can bankrupt the shared metrics store for **everyone**. Governing
  cardinality is a platform responsibility, the same way you govern CPU with quotas.
- **Observability is what makes SLOs possible.** You cannot have a Service Level
  Objective (Module 11.7) without a Service Level Indicator, and an SLI is just a
  well-chosen signal. The discipline starts here.

---

## 3. Mental model

Hold three pictures in your head for the rest of the phase.

**1. Pillars answer different questions; correlation is the payoff.**

```text
            METRICS                 LOGS                   TRACES
         (aggregate numbers)   (event detail)        (one request's path)
   ┌───────────────────┐   ┌──────────────────┐   ┌──────────────────────┐
   │ error rate rising │──▶│ which errors?    │──▶│ which hop failed, and │
   │ (alert fires)     │   │ (exact messages) │   │ where did time go?    │
   └───────────────────┘   └──────────────────┘   └──────────────────────┘
        "something is wrong"   "what, exactly"        "why, across services"

   The value is the ARROWS: jump metric → log → trace on a shared trace_id.
```

**2. Monitoring is a flashlight; observability is turning the lights on.**
A flashlight shows you where you already pointed it (the dashboards you pre-built).
Observability lights the whole room so you can look wherever the new problem is.

**3. Every signal has a price tag.**

```text
   cheap, coarse ───────────────────────────────▶ rich, expensive
   metrics            structured logs             traces (sampled)
   (aggregate)        (per event)                 (per request)
     ▲                                               ▲
     │ cardinality is the hidden cost here           │ sampling is the lever here
```

The engineering is choosing the cheapest signal that can still answer the question,
and spending the expensive signals only where they earn it.

---

## 4. Minimal implementation

You do not need a cluster to feel the core idea. The simplest possible "metric" is a
counter you increment and expose as text — the same format Prometheus scrapes
(Module 11.3). And the simplest way to *feel cardinality* is to multiply label
cardinalities and watch the series count explode.

A hand-rolled Prometheus exposition looks exactly like this:

```text
# HELP http_requests_total Total HTTP requests.
# TYPE http_requests_total counter
http_requests_total{method="GET",status="200",route="/health"} 42
http_requests_total{method="GET",status="500",route="/checkout"} 3
```

Each unique `{...}` label set is **one time series**. Count them for a realistic
label scheme and the problem is obvious:

```python
# cardinality.py — feel the explosion before a backend feels it for you
labels = {
    "method": 4,     # GET, POST, PUT, DELETE
    "status": 5,     # 2xx, 3xx, 4xx, 5xx, other
    "route":  200,   # templated routes: /users/{id}, not /users/42
    "pod":    50,    # replicas scraped
}
series = 1
for name, cardinality in labels.items():
    series *= cardinality
print(f"series for one metric: {series:,}")      # 200,000

# now add a high-cardinality label by mistake:
series_with_userid = series * 1_000_000          # 1M users
print(f"with user_id label:    {series_with_userid:,}")   # 200,000,000,000
```

The first number is fine. The second is a dead metrics store. That multiplication —
not any fancy tool — is the single most important intuition in this phase. The lab
turns it into a hands-on experiment and pairs it with a signals-mapping exercise.

---

## 5. Hands-on lab

You will map RED, USE, and the four golden signals onto a concrete service, then run
a tiny experiment that makes cardinality explosion visceral — all locally, with
nothing but Python.

➡️ **[Start the lab: Map the signals, feel the cardinality](./lab/README.md)**

---

## 6. Production considerations

- **Decide retention per signal.** Metrics are cheap — keep them for months. Raw
  logs and traces are expensive — keep a short hot window (days) and sample or
  archive the rest. One retention policy for all three wastes money or loses detail.
- **Budget cardinality like a resource.** Set limits (per-tenant series caps,
  `metric_relabel_configs` to drop risky labels) *before* a team DDoSes the shared
  store. Treat "max active series per namespace" as a quota.
- **Sample traces deliberately.** 100% tracing is unaffordable and usually
  unnecessary. Start with a low head-sampling rate plus **tail sampling that keeps
  all errors and slow requests** (Module 11.2). Record the sampling rate as metadata
  so you can scale counts back up.
- **Standardize or drown.** Hundreds of services each inventing their own metric
  names and log formats is unqueryable. Mandate **semantic conventions**
  (OpenTelemetry's naming) so `http.server.request.duration` means the same thing
  everywhere. Consistency *is* the platform value.
- **Instrument the paved road once.** Bake RED metrics, structured logging, and trace
  context into the service template so every new service is observable by default —
  the TVP move from Module 01.1 applied to telemetry.

## 7. Common mistakes

- **Treating "we have dashboards" as observability.** — Pre-built dashboards are
  monitoring; they answer only the questions you already thought of. *Fix:* invest in
  high-dimensional, explorable telemetry you can query ad hoc, not just a wall of
  fixed graphs.
- **Alerting on causes instead of symptoms.** — A page for "CPU is 90%" fires when
  nothing is actually wrong and misses real user pain. *Fix:* alert on
  user-facing **symptoms** (latency, error rate, SLO burn — Module 11.7); use
  resource metrics to *diagnose*, not to page.
- **Averaging latency.** — A mean hides the tail where users suffer and is skewed by
  fast errors. *Fix:* use percentiles (p95/p99) and separate success from failure
  latency.
- **High-cardinality labels.** — Putting `user_id`, request ID, or a raw URL in a
  metric label explodes series count and melts the store. *Fix:* keep identifiers in
  logs/traces; labels are for bounded dimensions (status, method, route template).
- **Unstructured logs.** — Free-text logs cannot be filtered or aggregated reliably.
  *Fix:* emit structured (JSON) logs with consistent keys from day one.
- **Collecting everything "just in case."** — Unbounded collection is how
  observability bills rival compute bills. *Fix:* collect against **questions you
  intend to answer** and sample the expensive signals.

## 8. Assessment

**Knowledge checks**

1. In one sentence each, define monitoring and observability, and state how they
   relate.
2. For each pillar (metrics, logs, traces), give one question it answers best and one
   it answers poorly.
3. What do RED and USE each measure, and when do you reach for one versus the other?
4. Why does adding a `user_id` label to a metric endanger a shared metrics backend?
5. Why can't you trace 100% of requests at scale, and what does tail sampling keep?

**Concept exercise**

> Explain to a skeptical engineer what observability gives them **without using the
> words "Prometheus," "Grafana," "metric," "log," or "trace."** Describe the outcome
> — what they can *do* at 2am that they could not before.

**Trade-off / debugging exercise**

> A team's dashboard shows average latency at a healthy 80ms, yet customers are
> complaining checkout is slow and occasionally fails. CPU and memory look fine.
> Explain what the dashboard is hiding, which signals you would add, and in what
> order you would use metrics, logs, and traces to find the cause.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Monitoring = alerting on predefined signals (known questions);
  observability = a system property letting you answer new, unpredicted questions
  from existing telemetry. Monitoring is a subset of what observability enables.
- **Q2:** Metrics: great for trends/alerts, poor for a single request's detail. Logs:
  great for what exactly happened in one event, poor/expensive for aggregate trends.
  Traces: great for where time went across services, poor as a complete record
  (sampled).
- **Q3:** RED (Rate, Errors, Duration) measures request-driven *work*; USE
  (Utilization, Saturation, Errors) measures the *resources* doing the work. RED for
  services, USE for nodes/disks/queues.
- **Q4:** `user_id` is unbounded; each value creates a new time series, multiplying
  cardinality into the millions and exhausting the store's memory — and in a shared
  store that harms every tenant.
- **Q5:** Volume is too high to store every trace affordably; tail sampling keeps the
  *interesting* traces (errors and slow requests) and discards routine fast successes.
- **Debugging:** The average hides the tail — p99 is likely terrible even though p50
  is 80ms, and fast 5xx errors drag the mean *down*. Add percentile latency split by
  status and a request/error rate. Use metrics to confirm the p99 and error spike,
  logs to see *which* errors, and a trace of a slow checkout to find the offending
  downstream hop.

</details>

---

## 9. Further reading

- Google — [SRE Book: Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/) (the four golden signals)
- Google — [SRE Workbook: Implementing SLOs](https://sre.google/workbook/implementing-slos/)
- OpenTelemetry — [Observability primer](https://opentelemetry.io/docs/concepts/observability-primer/)
- Tom Wilkie — [The RED Method](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/)
- Brendan Gregg — [The USE Method](https://www.brendangregg.com/usemethod.html)
- Prometheus — [Metric and label naming best practices](https://prometheus.io/docs/practices/naming/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 9 · Observability Engineering](../README.md)
· _Next:_ [Module 11.2 — OpenTelemetry →](../02-opentelemetry/)
