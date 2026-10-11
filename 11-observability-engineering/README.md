# 11 · Observability Engineering

> You can now build platforms *on* Kubernetes (Phases 3–10). But a platform you
> cannot **see into** is a platform you cannot operate, improve, or trust. This
> phase turns you from someone who *installs* Prometheus into someone who *designs
> the signals* a platform runs on — metrics, logs, and traces unified through
> OpenTelemetry, surfaced in Grafana, and governed by SLOs and error budgets.

**Phase 9 · 8 modules · ~14–20 hours**

## Why observability?

Every platform you have built so far has a blind spot. In Project 1 you onboarded
teams; in Phase 8 you delivered them with GitOps; in Phase 10 you taught the API new
nouns. None of it tells you whether any of it is **working right now** — whether a
deploy made latency worse, which team's runaway query is saturating a node, or why a
developer's request died three services deep.

The reflex is to "add monitoring": a CPU graph, a uptime check, a Slack alert. That
is where most teams stop, and it is not enough. **Monitoring** answers questions you
already knew to ask. **Observability** is the property that lets you ask *new*
questions — about failures you did not predict — from the data your systems already
emit. At platform scale, with hundreds of services you did not write, you cannot
predict the failures. You need observability.

This phase builds that capability from first principles:

- **The theory** — monitoring vs observability, the three pillars (metrics, logs,
  traces), RED / USE / the four golden signals, and the two costs that govern every
  design decision: **cardinality** and **sampling**.
- **The standard** — OpenTelemetry, the vendor-neutral way to instrument once and
  export anywhere, so your platform is never captive to one backend.
- **The stack** — the open-source **LGTM** stack (Loki for logs, Grafana for
  visualization, Tempo for traces, and Mimir / Prometheus for metrics), which you
  will run locally and for free.
- **The discipline** — SLIs, SLOs, SLAs, and multi-window burn-rate alerting, so you
  alert on **user pain**, not on every twitch of a CPU graph.
- **The strategy** — what a *platform team* observes that application teams do not,
  and how to turn signals into runbooks and a paging policy.

Everything here feeds directly into **Project 3 · Observability Platform** (the next
phase), where you will assemble these components into a single self-service product
that every team consumes.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Observability Fundamentals](./01-observability-fundamentals/) | Monitoring vs observability; the three pillars; RED/USE/four golden signals; why cardinality and sampling govern cost. | A signals map for a service and a cardinality-explosion experiment. |
| 2 | [OpenTelemetry](./02-opentelemetry/) | The OTel data model; SDKs and auto-instrumentation; the Collector (agent + gateway); processors and exporters; head vs tail sampling. | An OTel Collector (DaemonSet agent + gateway) on kind receiving telemetry from a sample service. |
| 3 | [Metrics with Prometheus](./03-metrics-with-prometheus/) | Scrape/store/query architecture; metric types; PromQL; ServiceMonitors; recording rules; remote write for long-term storage. | PromQL for error rate, p99 latency, and namespace CPU against a scraped app. |
| 4 | [Logging with Loki](./04-logging-with-loki/) | Loki's label-indexed architecture; LogQL; why labels must stay low-cardinality; structured logging; retention. | LogQL queries that filter, parse JSON, and compute an error rate from log lines. |
| 5 | [Distributed Tracing with Tempo](./05-distributed-tracing-with-tempo/) | Traces, spans, and context propagation; W3C TraceContext; Tempo's architecture; TraceQL; exemplars linking the three pillars. | A trace queried in Grafana and linked from a log line and a metric exemplar. |
| 6 | [Grafana Dashboards](./06-grafana-dashboards/) | Dashboard design principles; variables and templating; mixed data sources; dashboards as code with Grafonnet; versioning in Git. | A Platform Overview Dashboard delivered as Jsonnet (and importable JSON). |
| 7 | [SLOs and Error Budgets](./07-slos-and-error-budgets/) | SLI vs SLO vs SLA; error budgets; multi-window multi-burn-rate alerting; SLO tooling (Sloth, Pyrra). | A Sloth `PrometheusServiceLevel` generating recording rules and burn-rate alerts. |
| 8 | [Platform Observability Strategy](./08-platform-observability-strategy/) | What a platform team observes vs app teams; golden signals for platform services; GitOps and cluster signals; paging and runbooks. | A platform observability strategy worksheet, SLO catalog, and runbook. |

Work them in order — the theory in Module 1 governs every design choice that
follows, and Modules 3–5 each stand up one pillar of the stack you will unify in
Module 6 and govern in Module 7.

## Learning objectives

By the end of this phase you will be able to:

- Explain the difference between monitoring and observability, and choose the right
  signal (metric, log, or trace) for a given question.
- Instrument a service with OpenTelemetry and route its telemetry through a
  Collector to the right backend, reasoning about sampling and cardinality cost.
- Write PromQL and LogQL to answer real operational questions, and query distributed
  traces with TraceQL to follow a request across services.
- Build dashboards as code and correlate metrics, logs, and traces through exemplars
  and shared labels.
- Define SLOs and error budgets for platform services and alert on budget burn rate
  with multi-window alerts instead of noisy threshold alerts.
- Design an observability strategy for a platform team: what to watch, who to page,
  and how every alert links to a runbook.

## Prerequisites

- [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — you will
  deploy workloads, Services, and DaemonSets throughout.
- [Phase 7 · Kubernetes Package Management](../07-kubernetes-package-management/) —
  every lab installs its stack with Helm.
- [Phase 8 · GitOps](../08-gitops/) — Module 8 reasons about observing Argo CD sync
  pipelines, and the SLO examples target platform services you have already met.
- Everything from [Module 00 · Orientation](../00-orientation/): Docker, `kubectl`,
  [kind](https://kind.sigs.k8s.io/), and [Helm](https://helm.sh/). A couple of labs
  optionally use Docker Compose; Module 2's app sketch references a Go toolchain but
  does not require you to build it.

Every lab runs **free** on a local kind cluster or with Docker Compose — there is no
cloud spend in this phase.

## A note on the labs

These labs are not throwaway demos: together they assemble the **LGTM stack**
(Loki, Grafana, Tempo, Mimir/Prometheus) plus OpenTelemetry and Sloth — exactly the
components you will wire into a single product in **Project 3 · Observability
Platform**. Keep the values files, dashboards, PromQL, and SLO definitions you
write here; they are the starter kit for that project and a strong portfolio piece
that shows you can design what a platform *observes*, not just install the tools.

---

Start with [**01 · Observability Fundamentals →**](./01-observability-fundamentals/)
