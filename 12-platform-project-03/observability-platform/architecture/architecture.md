# Architecture — Observability Platform

This document describes the observability platform: what it's made of, how telemetry
flows from applications to Grafana, and the reasoning behind the design. Decisions
with meaningful trade-offs are captured as [ADRs](./decisions/).

## Problem statement

The platform now runs multiple teams' services ([Project 1](../../../04-platform-project-01/))
delivered by GitOps ([Project 2](../../../09-platform-project-02/)) — but nobody can
*see* what's happening inside. When a service is slow, when ArgoCD stops syncing, or
when an SLO is burning, the platform team needs answers from the system's external
outputs, not guesswork. This project delivers the **monitoring plane**: a unified
metrics/logs/traces stack with SLOs for the platform's own services.

## Design goals

- **One collection standard.** Applications emit telemetry once, via OpenTelemetry,
  regardless of backend.
- **All three pillars, correlated.** Metrics, logs, and traces in one place (Grafana),
  linkable to each other.
- **Platform-owned, team-consumed.** Teams get observability by default; they don't
  each stand up their own Prometheus.
- **SLO-driven.** The platform defines SLOs for its own services and alerts on
  **burn rate**, not every blip.
- **Delivered as code.** Dashboards, alerts, and SLOs live in Git (Pass 2: via
  ArgoCD), not hand-clicked in a UI.

## How telemetry flows

```text
   App (OTel SDK)  ──OTLP──►  OTel Collector
                                ├─ DaemonSet  : node/host metrics + pod logs
                                └─ Deployment : trace gateway (batch, tail-sample)
                                     │
            ┌────────────────────────┼────────────────────────┐
            ▼                        ▼                         ▼
      Prometheus                   Loki                      Tempo
      (metrics, PromQL)            (logs, LogQL)             (traces, TraceQL)
            │                        │                         │
            └────────────────────────┴────────────┬────────────┘
                                                   ▼
                                                Grafana
                           (dashboards, Explore, alerting, SLO burn-rate)
```

The **collector** is the seam: applications talk OTLP to it and never need to know
whether metrics land in Prometheus or Mimir, or traces in Tempo or Jaeger. Swap a
backend without touching a single app ([ADR-015](./decisions/ADR-015-why-opentelemetry.md)).

## Component inventory

| Component | Role | Pass | Introduced in |
|-----------|------|:----:|---------------|
| OpenTelemetry SDK | In-app instrumentation (metrics, traces) | **1** | [Phase 9 · OTel](../../../11-observability-engineering/02-opentelemetry/) |
| OTel Collector (DaemonSet) | Per-node host metrics + pod log collection | **1** | [Phase 9 · OTel](../../../11-observability-engineering/02-opentelemetry/) |
| OTel Collector (gateway Deployment) | Trace aggregation, batching, tail sampling | **1** | [Phase 9 · OTel](../../../11-observability-engineering/02-opentelemetry/) |
| Prometheus (kube-prometheus-stack) | Metrics store + PromQL + alert rules | **1** | [Phase 9 · Prometheus](../../../11-observability-engineering/03-metrics-with-prometheus/) |
| Loki | Log aggregation + LogQL | **1** | [Phase 9 · Loki](../../../11-observability-engineering/04-logging-with-loki/) |
| Tempo | Distributed tracing backend + TraceQL | **1** | [Phase 9 · Tempo](../../../11-observability-engineering/05-distributed-tracing-with-tempo/) |
| Grafana | Dashboards, Explore, alerting | **1** | [Phase 9 · Grafana](../../../11-observability-engineering/06-grafana-dashboards/) |
| Sloth | Generates SLO recording + burn-rate alert rules | **1** | [Phase 9 · SLOs](../../../11-observability-engineering/07-slos-and-error-budgets/) |
| Alertmanager | Routes alerts (→ Slack) | 2 | [Phase 9 · SLOs](../../../11-observability-engineering/07-slos-and-error-budgets/) |
| ArgoCD delivery | The whole stack delivered by GitOps | 2 | [Project 2](../../../09-platform-project-02/) |
| GCS | Long-term storage for logs/traces | 2 | [Phase 14 · FinOps](../../../18-finops-and-cost-engineering/) |

## Collector topology: DaemonSet + gateway

Two collector roles, deliberately separated
([ADR-017](./decisions/ADR-017-collector-topology.md)):

- **DaemonSet (agent)** — one per node, close to the workloads. Scrapes node/host
  metrics and tails pod logs. Cheap, local, no single bottleneck.
- **Deployment (gateway)** — a horizontally-scalable aggregation tier. Receives OTLP
  traces, does **batching** and **tail-based sampling** (keep error/slow traces, drop
  most of the rest), and fans out to the backends. Centralizing sampling here is why
  tail sampling works at all — a single agent can't see a whole trace.

## SLOs and burn-rate alerting

The platform defines SLOs for its *own* services (ArgoCD, Prometheus, the gateway),
not just app teams' services:

- An **SLI** is a measured ratio (e.g. good syncs / total syncs).
- An **SLO** is the target (e.g. 99.9% over 30 days).
- The **error budget** is `1 − SLO`; alerts fire on **burn rate** (how fast you're
  spending the budget), using multi-window multi-burn-rate alerts so you page on fast
  burns and ticket on slow ones — not on every transient error.

[Sloth](./decisions/ADR-016-why-sloth.md) turns a short SLO spec into the Prometheus
recording and alerting rules that implement this, so you don't hand-write brittle
burn-rate PromQL.

## Security & cost posture

- Observability components run hardened (non-root, read-only where supported),
  consistent with the Project 1 baseline.
- **Cardinality and volume are the cost drivers.** High-cardinality labels and 100%
  trace retention are what make an observability bill explode; the gateway's tail
  sampling and sane label hygiene keep it in check (a FinOps concern,
  [Phase 14](../../../18-finops-and-cost-engineering/)).
- Long-term storage goes to cheap object storage (GCS) in Pass 2; local retention is
  short.

## Known limitations

- Pass 1 runs single-replica, local-storage components sized for a laptop — not HA,
  not durable. Pass 2 adds GitOps delivery and object storage.
- No Alertmanager routing to a real destination in Pass 1 (alerts are visible in
  Grafana/Prometheus but not paged).
- The stack is memory-hungry; very small machines may need a reduced install.

## Production considerations

- Deliver the whole stack via GitOps so the observability platform is itself
  reproducible and auditable (Pass 2).
- Watch the watcher: the observability stack is tier-1 infrastructure. Give
  Prometheus/Grafana their own SLOs and alert on *their* health (Module 11.8).
- Control cardinality aggressively — it's the difference between an affordable and an
  unaffordable platform.
- Link every alert to a runbook in its annotations; an alert with no runbook is noise.

## Decisions

See the [ADRs](./decisions/):

- [ADR-011 — Why Tempo over Jaeger](./decisions/ADR-011-why-tempo.md)
- [ADR-015 — Why OpenTelemetry as the collection standard](./decisions/ADR-015-why-opentelemetry.md)
- [ADR-016 — Why Sloth for SLOs](./decisions/ADR-016-why-sloth.md)
- [ADR-017 — Why a DaemonSet + gateway collector topology](./decisions/ADR-017-collector-topology.md)
