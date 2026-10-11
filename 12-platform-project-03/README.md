# 12 · Platform Project 03 — Observability Platform

> Your third platform build. [Project 1](../04-platform-project-01/) gave teams a safe
> cluster; [Project 2](../09-platform-project-02/) put Git in charge of it. Now you'll
> make the platform **observable**: a production-grade metrics, logs, and traces stack
> — delivered via GitOps — with **SLOs defined for the platform itself**.

**This is a project, not a lesson.** It consolidates Observability (Phase 9) with the
GitOps delivery backbone (Project 2) and package management (Phase 6) into one
buildable system.

➡️ **[Open the project: Observability Platform](./observability-platform/README.md)**

## At a glance

| | |
|---|---|
| **Goal** | A full OpenTelemetry + Prometheus/Loki/Tempo/Grafana stack, delivered by GitOps, with SLOs for the platform's own services. |
| **You'll use** | Observability (Phase 9), GitOps/ArgoCD (Project 2), Helm/Kustomize (Phase 6). |
| **Pass 1 (now)** | Build the LGTM + OTel stack locally on `kind`, instrument a sample app, see metrics/logs/traces in Grafana, define one SLO + a burn-rate alert. Free. |
| **Pass 2 (later)** | Deliver the whole stack via ArgoCD, add long-term storage (GCS), Alertmanager → Slack, runbook-linked alerts, and SLOs for ArgoCD/Prometheus/the gateway. |
| **Deliverable** | A reproducible observability stack + dashboards-as-code + SLO definitions + runbooks. |
| **Effort** | ~8–12 hours for Pass 1. |

## Why a project here?

You can read about the three pillars, RED/USE, and error budgets — but observability
only becomes real when you trace one request from an instrumented app through the
collector into Prometheus, Loki, and Tempo, see it in Grafana, and watch a burn-rate
alert fire when you break an SLO. This project also produces portfolio-grade
dashboards-as-code and SLO definitions, and it's what makes **every** later platform
service measurable.

Start here: **[observability-platform/](./observability-platform/README.md)**.

---

_Previous:_ [11 · Observability Engineering](../11-observability-engineering/)
· _Next:_ [13 · Security and Policy Engineering](../13-security-and-policy-engineering/)
