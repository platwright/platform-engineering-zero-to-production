# ADR-016 — Why Sloth for SLOs

## Status

Accepted
Date: 2026-10-10

## Context

The platform defines SLOs for its services and alerts on **error-budget burn rate**.
Correct multi-window, multi-burn-rate alerting (the Google SRE pattern) requires a set
of Prometheus recording rules and alert rules that are fiddly and error-prone to write
by hand — and easy to get subtly wrong, producing either alert storms or blind spots.
We want SLOs defined declaratively, with the burn-rate machinery generated for us.

Constraints: we already run Prometheus; we want SLOs as code in Git; and we want the
generated rules to follow the well-known multi-window burn-rate methodology.

## Decision

We will use **Sloth** to define SLOs declaratively (a `PrometheusServiceLevel`
spec) and generate the Prometheus recording and alerting rules.

## Consequences

- **Easier:** an engineer writes a short SLO spec (service, objective, SLI queries)
  and Sloth generates correct multi-window burn-rate alerts and recording rules — no
  hand-written burn-rate PromQL.
- **Easier:** SLOs live as code in Git, are reviewable, and are consistent across
  services; the generated rules plug straight into Prometheus/Alertmanager.
- **Harder / trade-offs:** another tool in the pipeline; teams must express SLIs as
  good/total event queries, which takes some learning; very bespoke alerting may
  outgrow the generator.

## Alternatives considered

- **Hand-written recording + alert rules** — maximum control, but error-prone and
  inconsistent across teams. Rejected as the default.
- **Pyrra** — a strong alternative that also generates SLO rules and ships a UI;
  equally valid. We pick Sloth for its simple, Git-friendly spec; Pyrra is a
  reasonable swap.
- **A SaaS SLO product** — less to run, but cost and lock-in, and outside the
  open-source approach.

## References

- [Sloth](https://sloth.dev/)
- [Google SRE Workbook — Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- [Phase 9 · SLOs and Error Budgets](../../../../11-observability-engineering/07-slos-and-error-budgets/)
