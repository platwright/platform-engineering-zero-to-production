# Project 3 — Observability Platform

> Deploy a production-grade observability platform on Kubernetes — **OpenTelemetry**
> for collection; **Prometheus** (metrics), **Loki** (logs), and **Tempo** (traces)
> for storage; **Grafana** for visualization and alerting — delivered and managed via
> **GitOps**, with **SLOs defined for the platform itself**.

This project sits right after [Phase 9 · Observability](../../11-observability-engineering/)
and builds on the [Project 2](../../09-platform-project-02/) GitOps backbone. As
before, you build it in **two passes**.

---

## The two-pass approach

```text
PASS 1 — Build it now (free, local, on kind)
  • The LGTM + OTel stack installed with Helm on a local cluster
  • A sample app instrumented with the OpenTelemetry SDK (metrics + traces)
  • OTel Collector: DaemonSet (node metrics/logs) + Deployment (trace gateway)
  • Grafana wired to Prometheus, Loki, and Tempo — see all three pillars
  • One SLO defined (Sloth) + a multi-window burn-rate alert that you make fire
  • A Platform Overview Dashboard as code

PASS 2 — Harden to production (as later phases/pieces allow)
  • The entire stack delivered by ArgoCD (from Project 2)              → Phase 7 (GitOps)
  • Long-term storage in GCS (Loki/Tempo) + Mimir/remote-write for metrics
  • Alertmanager → Slack; every alert annotation links to a runbook
  • SLOs for ArgoCD, Prometheus, and the API gateway
```

---

## Target architecture

```text
   Applications (instrumented with the OTel SDK)
        │  OTLP (metrics, logs, traces)
        ▼
   OTel Collector
     ├─ DaemonSet  (per-node: host metrics, pod logs)
     └─ Deployment (gateway: trace aggregation, tail sampling, batching)
        │
        ├──────────────┬───────────────┐
        ▼              ▼               ▼
   Prometheus       Loki            Tempo          Alertmanager
   (metrics)        (logs)          (traces)       (alert routing → Slack)
        │              │               │
        └──────────────┴───────┬───────┘
                               ▼
                           Grafana
              (dashboards, Explore, alerting, SLO burn-rate)
                               │
                               ▼
                 GCS — long-term storage (Pass 2)
```

Mapped to the IDP **five planes**
([Module 01.4](../../01-platform-foundations/04-the-internal-developer-platform/README.md)),
this project is the **monitoring plane** — the one that lets the platform team (and
every stream team) see what's happening, what it costs, and whether SLOs hold.

See [architecture/architecture.md](./architecture/architecture.md) for the full
component inventory and the decisions behind it.

---

## Requirements

From the course outline. The **Pass** column shows what you build now vs the phase
that completes it later.

| # | Requirement | Pass | Taught in |
|---|-------------|------|-----------|
| 1 | OTel Collector as DaemonSet (logs/metrics) + Deployment (traces) | **1** | [Phase 9 · OpenTelemetry](../../11-observability-engineering/02-opentelemetry/) |
| 2 | Prometheus + Loki + Tempo + Grafana running, all three pillars visible | **1** | [Phase 9](../../11-observability-engineering/) |
| 3 | A Platform Overview Dashboard in code | **1** | [Phase 9 · Grafana](../../11-observability-engineering/06-grafana-dashboards/) |
| 4 | An SLO + burn-rate alert (make it fire) | **1** | [Phase 9 · SLOs](../../11-observability-engineering/07-slos-and-error-budgets/) |
| 5 | Entire stack deployed via ArgoCD | 2 | [Project 2 · GitOps](../../09-platform-project-02/) |
| 6 | Burn-rate alert → Slack via Alertmanager; runbooks linked | 2 | [Phase 9 · SLOs](../../11-observability-engineering/07-slos-and-error-budgets/) |
| 7 | Long-term storage (GCS) for logs/traces; metrics retention | 2 | [Phase 14 · FinOps](../../18-finops-and-cost-engineering/) (cost) |

**Stretch goals:** trace-to-log correlation in Grafana; exemplars linking Prometheus
metrics to Tempo traces; Grafana OnCall for schedules.

---

## Prerequisites

- Completed [Phase 6](../../07-kubernetes-package-management/),
  [Phase 7](../../08-gitops/), [Phase 9](../../11-observability-engineering/), and the
  [Project 2](../../09-platform-project-02/) GitOps platform.
- Tools: Docker, `kubectl`, `kind`, `helm`. A machine with **≥ 8 GB RAM free** — the
  LGTM stack is heavier than earlier labs.

---

## Build it

The full, staged walkthrough is the project's build guide:

➡️ **[Build guide — step by step](./build-guide.md)**

Quick start:

```bash
# From this project directory
./scripts/bootstrap.sh      # kind cluster + the LGTM + OTel stack via Helm
# ... instrument the app, explore Grafana, make the SLO alert fire ...
./scripts/cleanup.sh        # tear everything down
```

---

## Repository layout

```text
observability-platform/
├── README.md                 # you are here
├── build-guide.md            # the staged build walkthrough
├── architecture/
│   ├── architecture.md       # full architecture + component inventory
│   ├── decisions/            # ADRs (OTel, Tempo vs Jaeger, Sloth, agent topology)
│   └── diagrams/
├── config-repo/              # GitOps-delivered config (Pass 2 wires these into ArgoCD)
│   ├── platform/
│   │   ├── otel-collector/   # DaemonSet + gateway collector configs
│   │   ├── prometheus/       # kube-prometheus-stack values + rules
│   │   ├── loki/             # Loki values
│   │   ├── tempo/            # Tempo values
│   │   ├── grafana/          # datasources + dashboard provisioning
│   │   └── alertmanager/     # routing → Slack (Pass 2)
│   └── slos/                 # Sloth SLO definitions
├── dashboards/               # dashboards as code (JSON/Jsonnet)
├── docs/
│   ├── onboarding.md         # how a team gets their service observable
│   └── runbooks/             # one per alert
└── scripts/
    ├── bootstrap.sh          # kind + Helm install the stack
    └── cleanup.sh            # tear down
```

---

## Portfolio-ready checklist

This project is portfolio-ready (and "done" for Pass 1) when you can tick:

- [ ] Clear problem statement and architecture diagram in the README
- [ ] Reproducible from scratch: `./scripts/bootstrap.sh` builds it on a clean machine
- [ ] A sample app instrumented with OTel; its metrics and traces reach the backends
- [ ] OTel Collector running as **both** a DaemonSet and a gateway Deployment
- [ ] Grafana shows **metrics (Prometheus), logs (Loki), and traces (Tempo)**
- [ ] A **Platform Overview Dashboard** provisioned from code (not a manual export)
- [ ] An **SLO** defined and a **burn-rate alert** you deliberately triggered
- [ ] A [runbook](./docs/runbooks/) linked from that alert
- [ ] At least one [ADR](./architecture/decisions/) explaining a key decision
- [ ] Cleanup works and leaves nothing running

Pass 2 adds: GitOps delivery of the whole stack, long-term GCS storage, Slack
alerting, and SLOs for ArgoCD/Prometheus/the gateway.

---

## Cost & cleanup

- **Pass 1 costs nothing** — it runs entirely on a local `kind` cluster. It is
  **memory-hungry**, though: close other apps and give Docker ≥ 8 GB.
- **Pass 2 touches the cloud** (GCS for long-term storage). Set a budget alert, and
  mind that observability data volume is a real cost driver (a FinOps topic,
  [Phase 14](../../18-finops-and-cost-engineering/)).
- Every build step has a matching cleanup.

```bash
./scripts/cleanup.sh         # removes the kind cluster and all Pass 1 resources
```

---

## Architecture decisions

- [ADR-011 — Why Tempo over Jaeger](./architecture/decisions/ADR-011-why-tempo.md)
- [ADR-015 — Why OpenTelemetry as the collection standard](./architecture/decisions/ADR-015-why-opentelemetry.md)
- [ADR-016 — Why Sloth for SLOs](./architecture/decisions/ADR-016-why-sloth.md)
- [ADR-017 — Why a DaemonSet + gateway collector topology](./architecture/decisions/ADR-017-collector-topology.md)

---

_Previous:_ [11 · Observability Engineering](../../11-observability-engineering/)
· _Next:_ [13 · Security and Policy Engineering](../../13-security-and-policy-engineering/)
