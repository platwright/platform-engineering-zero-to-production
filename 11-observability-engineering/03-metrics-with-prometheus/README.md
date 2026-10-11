# Module 11.3 — Metrics with Prometheus

> Prometheus is the de-facto standard for metrics in the cloud-native world — a
> pull-based time-series database with a query language (**PromQL**) built for the
> questions platform engineers actually ask. This module covers how it scrapes,
> stores, and queries metrics, the four metric types, and how the Operator turns
> "monitor this service" into a one-object declaration.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 11.1](../01-observability-fundamentals/), a kind cluster,
`kubectl`, and [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Explain Prometheus's **pull model** and its scrape → store → query architecture.
- Choose the right **metric type** — counter, gauge, histogram, summary.
- Write **PromQL** for rate, error ratio, percentile latency, and aggregation.
- Use **ServiceMonitor / PodMonitor** to declare scrape targets with the Operator.
- Know when to add **recording rules** and **remote write** for scale and retention.

---

## 1. Concept

### Architecture: scrape, store, query

Prometheus is three things in one binary:

- **Scrape** — on a schedule, Prometheus **pulls** metrics by making an HTTP GET to
  each target's `/metrics` endpoint, which returns the current values in a simple
  text format. This **pull model** is the defining design choice: targets just expose
  a page; Prometheus decides when to read it. That makes targets simpler (no push
  config, no credentials to a remote), gives Prometheus control over load, and makes
  "is the target up?" a free health signal (the `up` metric).
- **Store** — samples land in a local **time-series database (TSDB)** on disk,
  optimized for many numeric series written append-only over time. Each sample is
  `(metric name + labels) → (timestamp, float64)`.
- **Query** — **PromQL** reads that TSDB to answer questions, power dashboards
  (Module 11.6), and evaluate alert and recording rules.

A **time series** is uniquely identified by its metric name plus its label set —
`http_requests_total{method="GET", code="200"}` is a *different* series from
`...{code="500"}`. This is where the cardinality lesson from Module 11.1 bites: every
distinct label combination is another series the TSDB must hold in memory and on disk.

### Service discovery: how targets are found

Hardcoding a list of IPs to scrape does not survive Kubernetes, where Pods come and
go. Prometheus uses **service discovery** — in Kubernetes it watches the API for
Pods, Services, and Endpoints and builds its scrape list dynamically. The
**Prometheus Operator** (which you install via `kube-prometheus-stack`) wraps this in
CRDs so you never hand-edit Prometheus config:

- **ServiceMonitor** — "scrape the Pods behind this Service, on this port and path."
- **PodMonitor** — "scrape these Pods directly," for workloads without a Service.

You label a ServiceMonitor so the Prometheus instance selects it, and the Operator
regenerates Prometheus's config for you. Declaring telemetry as Kubernetes objects is
exactly the GitOps-friendly model a platform wants.

### Metric types

The exposition format has four types, and picking the right one matters:

- **Counter** — a value that only ever **goes up** (or resets to zero on restart):
  requests served, errors, bytes sent. You almost never read a counter raw; you take
  its **`rate()`** (per-second increase). `http_requests_total` is a counter.
- **Gauge** — a value that goes **up and down**: temperature, memory in use, queue
  depth, in-flight requests. Read it directly or with `avg`/`max` over time.
- **Histogram** — samples observations into **cumulative buckets** (e.g. "requests
  faster than 0.1s"), exposing `_bucket`, `_sum`, and `_count` series. The key power:
  you compute **percentiles** across instances *after the fact* with
  `histogram_quantile()`. This is how you get p99 latency.
- **Summary** — like a histogram but computes **quantiles client-side** at
  observation time. Cheaper to query but you **cannot aggregate** its quantiles
  across instances (a p99 of p99s is meaningless). Prefer histograms in distributed
  systems for exactly that reason.

### PromQL in one page

PromQL evaluates to **vectors**:

- An **instant vector** is the value of each matching series at one instant:
  `http_requests_total`.
- A **range vector** is a window of samples per series, written with `[5m]`:
  `http_requests_total[5m]`. Functions like `rate()` consume range vectors.

The moves you will use constantly:

- **`rate(counter[5m])`** — per-second average increase over the window. The
  foundation of every request/error-rate query.
- **Aggregation** — `sum`, `avg`, `max`, `count` with `by (label)` or
  `without (label)` to collapse series: `sum by (namespace) (...)`.
- **`histogram_quantile(0.99, ...)`** — a percentile from histogram buckets.
- **Label matchers** — `{code=~"5.."}` (regex), `{code!="200"}` (negation).

```promql
# the canonical service error ratio
sum(rate(http_requests_total{code=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))
```

### Recording rules, remote write, federation

- **Recording rules** pre-compute expensive or frequently used expressions on a
  schedule and save the result as a new series. Dashboards and alerts then read the
  cheap pre-computed series instead of re-running a heavy query every refresh.
- **Remote write** streams samples to an external, horizontally scalable, long-term
  store — **Thanos**, **Mimir**, or **VictoriaMetrics** — because a single
  Prometheus's local TSDB is capped by one node's disk and retention. In the LGTM
  stack, **Mimir** is the long-term metrics home.
- **Federation** lets one Prometheus scrape a curated, aggregated subset of another —
  an older pattern for hierarchies of Prometheis, now often superseded by remote
  write to a central store.
- **kube-state-metrics** is a companion exporter that turns Kubernetes **object
  state** (Deployments desired vs ready, Pod phase, resource requests) into metrics —
  distinct from **node-exporter** (node hardware) and **cAdvisor** (container
  CPU/memory). Together they give you USE signals for the whole cluster.

---

## 2. Why it matters for platform engineering

- **It is the metrics substrate of the whole platform.** Autoscaling (HPA), SLOs
  (Module 11.7), capacity planning, and chargeback (Phase 18) all read Prometheus.
  Getting it right underpins everything downstream.
- **ServiceMonitors make observability self-service.** A team adds a ServiceMonitor
  to its chart and is scraped automatically — no ticket to the platform team, no
  central config edit. That is the golden-path pattern applied to metrics.
- **Cardinality is a shared-fate risk.** One team's `user_id` label can exhaust the
  shared Prometheus's memory for everyone. You own the limits (`sample_limit`,
  `metric_relabel_configs`) that contain the blast radius.
- **Retention and scale are platform decisions.** When local TSDB is not enough, *you*
  choose and operate the remote-write backend (Mimir/Thanos). Teams should never feel
  that seam.

---

## 3. Mental model

Prometheus is a **polling librarian**: on a timer it visits every target's `/metrics`
page, copies down the current numbers, files them by name+labels, and answers
questions with PromQL.

```text
   targets expose /metrics            Prometheus                     consumers
   ┌────────────────────┐    scrape   ┌───────────────┐   PromQL   ┌─────────────┐
   │ app  :8080/metrics │ ◀────────── │  TSDB (local) │ ─────────▶ │ Grafana     │
   │ node :9100/metrics │ ◀────────── │  + rule eval  │ ─────────▶ │ Alertmanager│
   │ ksm  :8080/metrics │ ◀────────── │               │            │ HPA / SLOs  │
   └────────────────────┘             └───────┬───────┘            └─────────────┘
         ▲ discovered via                     │ remote_write
         ServiceMonitor/PodMonitor            ▼
                                     Mimir / Thanos (long-term, scalable)

   PULL, not push: targets are dumb pages; Prometheus decides when to read them.
```

Rule of thumb: **counters you `rate()`, gauges you read, histograms you
`histogram_quantile()`.** If you are writing `rate()` on something that is not a
counter, or a quantile on something that is not a histogram, stop and recheck the
type.

---

## 4. Minimal implementation

Before any Operator, see the pull model with nothing but a text page. A Prometheus
target is *just* an HTTP endpoint returning this:

```text
# HELP http_requests_total Total HTTP requests.
# TYPE http_requests_total counter
http_requests_total{code="200",method="get"} 1027
http_requests_total{code="500",method="get"} 3
# HELP inflight_requests In-flight requests right now.
# TYPE inflight_requests gauge
inflight_requests 5
```

Serve that from any process and point Prometheus at it with a three-line scrape job —
no Kubernetes required:

```yaml
# prometheus.yml — the smallest scrape config
scrape_configs:
  - job_name: demo
    static_configs:
      - targets: ["localhost:8080"]
```

```bash
prometheus --config.file=prometheus.yml   # scrapes localhost:8080/metrics every 15s
```

Now the counter is queryable. Its per-second rate and error ratio are one PromQL
expression each:

```promql
sum(rate(http_requests_total[1m]))                                  # total req/s
sum(rate(http_requests_total{code=~"5.."}[1m])) / sum(rate(http_requests_total[1m]))
```

That is the whole model: expose numbers on a page, let Prometheus pull them, ask
PromQL questions. The lab scales this up with the Operator and a real histogram.

---

## 5. Hands-on lab

You will install `kube-prometheus-stack` on kind, deploy a sample service, declare a
**ServiceMonitor** so Prometheus scrapes it, generate load, and write PromQL for
**error rate**, **p99 latency**, and **namespace CPU** — then add a recording rule.

➡️ **[Start the lab: PromQL against a scraped service](./lab/README.md)**

---

## 6. Production considerations

- **Guard cardinality hard.** Set `sample_limit` on scrapes and use
  `metric_relabel_configs` to drop risky labels *before* ingestion. Watch
  `prometheus_tsdb_head_series` and alert when a tenant's series count spikes.
- **Plan retention and remote write early.** Local TSDB retention is finite; decide
  up front whether long-term data lives in Mimir/Thanos and stream it via
  `remote_write`. Retrofitting history is painful.
- **Make Prometheus itself highly available.** Run redundant replicas (the Operator
  supports it) or front it with Thanos/Mimir; a single Prometheus is a single point
  of blindness. Back the TSDB with a PVC.
- **Scrape intervals cost money.** 15s is a sane default; 5s quadruples storage and
  scrape load versus 30s. Match interval to how fast you actually need to react.
- **Recording rules for hot queries.** Pre-compute the expressions dashboards and SLO
  alerts hit every evaluation; it cuts query load dramatically and keeps alerting
  responsive.
- **Secure `/metrics` and the UI.** Metrics can leak internals; the Prometheus UI and
  Alertmanager must not be publicly reachable. Scope RBAC and network policy.

## 7. Common mistakes

- **`rate()` on a gauge (or reading a counter raw).** — `rate()` assumes
  monotonic counters; on a gauge it is nonsense, and a raw counter is an
  ever-growing number nobody wants. *Fix:* `rate()` counters, read gauges directly.
- **High-cardinality labels.** — `user_id`, request path with IDs, or a raw URL as a
  label explodes series and OOMs Prometheus. *Fix:* bounded labels only; put
  identifiers in logs/traces and use route templates.
- **Summaries where you need cross-instance percentiles.** — Summary quantiles cannot
  be aggregated across replicas, so a fleet-wide p99 is impossible. *Fix:* use
  histograms and `histogram_quantile()`.
- **ServiceMonitor not selected.** — The label the Prometheus instance selects on is
  missing, so the target is silently never scraped. *Fix:* match the Operator's
  selector (e.g. the `release` label) and check the Targets page.
- **Averaging latency or rating over too-short a window.** — Means hide the tail and
  a `[1m]` rate on a 30s scrape is noisy. *Fix:* percentiles via histograms and a
  rate window at least 4× the scrape interval.
- **Treating local TSDB as durable, long-term storage.** — One node's disk and a
  short retention are not an archive. *Fix:* remote-write to Mimir/Thanos for
  long-term, scalable storage.

## 8. Assessment

**Knowledge checks**

1. Why does Prometheus **pull** metrics instead of having targets push them? Name two
   advantages.
2. For each of these, give the metric type: requests served, memory in use, request
   latency distribution. Why?
3. What does `rate(http_requests_total[5m])` compute, and why can't you use it on a
   gauge?
4. How does `histogram_quantile()` get you a p99 across many Pods when a summary
   cannot?
5. What does a ServiceMonitor declare, and what makes a given Prometheus select it?

**Concept exercise**

> Explain how you would measure a service's error rate and tail latency **without
> naming Prometheus or PromQL** — describe the raw numbers you would collect and the
> arithmetic you would do to them.

**Trade-off / debugging exercise**

> A team reports "our dashboard shows zero requests, but the app is clearly serving
> traffic." The app exposes `/metrics`, and other services are scraped fine. Walk
> through how you would diagnose it — from the Targets page to labels to the
> ServiceMonitor — and list three distinct root causes that produce this symptom.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Targets stay simple (just expose a page), Prometheus controls scrape
  timing/load, and reachability becomes a free `up` signal. (Also: no inbound
  credentials to targets; easy local testing by curling `/metrics`.)
- **Q2:** Counter (requests served — monotonic), gauge (memory — up and down),
  histogram (latency distribution — enables after-the-fact percentiles).
- **Q3:** The per-second average increase of the counter over 5 minutes. Gauges are
  not monotonic, so `rate()`'s "increase per second" is meaningless on them.
- **Q4:** Histograms expose raw cumulative buckets per series; you `sum` the bucket
  rates across Pods first, then compute the quantile — aggregation happens before the
  percentile. Summaries pre-compute the quantile per instance, and quantiles cannot be
  averaged, so a fleet p99 is impossible.
- **Q5:** A ServiceMonitor declares which Service's Pods to scrape, on which
  port/path/interval. A Prometheus selects it when its `serviceMonitorSelector`
  matches the ServiceMonitor's labels (commonly the `release` label).
- **Debugging:** Check the Targets page — is the target present and `up`? Causes:
  (1) ServiceMonitor label doesn't match the Prometheus selector, so it's never
  configured; (2) the Service port name/number in the ServiceMonitor doesn't match
  the Service, so nothing is scraped; (3) the metric exists but under different
  labels than the dashboard query expects (e.g. `code` vs `status`), so the query
  returns empty. Each yields "zero on the dashboard."

</details>

---

## 9. Further reading

- Prometheus — [Overview](https://prometheus.io/docs/introduction/overview/) and
  [Concepts: metric types](https://prometheus.io/docs/concepts/metric_types/)
- Prometheus — [Querying basics (PromQL)](https://prometheus.io/docs/prometheus/latest/querying/basics/)
  and [functions](https://prometheus.io/docs/prometheus/latest/querying/functions/)
- Prometheus Operator — [ServiceMonitor / PodMonitor design](https://prometheus-operator.dev/docs/developer/getting-started/)
- Prometheus — [Metric and label naming best practices](https://prometheus.io/docs/practices/naming/)
- Grafana — [Mimir](https://grafana.com/docs/mimir/latest/) and
  [Thanos](https://thanos.io/) for long-term, scalable metrics

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.2 — OpenTelemetry](../02-opentelemetry/)
· _Next:_ [Module 11.4 — Logging with Loki →](../04-logging-with-loki/)
