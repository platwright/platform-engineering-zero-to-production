# Lab — Design a platform observability strategy

> No cluster this time — the hardest observability work is **deciding what to watch and
> who to wake**. You will produce a platform observability strategy: classify what the
> platform observes versus what app teams observe, define golden signals and SLOs for
> the core platform services, design a paging policy routed by ownership, and write one
> runbook. This is the design document Project 3 implements.

**Estimated time:** ~60–90 minutes
**Type:** Design
**Deliverable:** A completed [`observability-strategy-worksheet.md`](./observability-strategy-worksheet.md),
a filled [`platform-slo-catalog.md`](./platform-slo-catalog.md), and one runbook written
from [`runbook-template.md`](./runbook-template.md).

## Objectives

- Draw the ownership line between platform, shared, and application observability.
- Define golden signals, SLOs, and paging for the platform's own services.
- Make every alert actionable by linking it to a runbook.

## Prerequisites

- [Module 11.8](../README.md) and the rest of Phase 9. No tools required — a text
  editor is enough.
- Starter files in this folder:
  [`observability-strategy-worksheet.md`](./observability-strategy-worksheet.md),
  [`platform-slo-catalog.md`](./platform-slo-catalog.md), and
  [`runbook-template.md`](./runbook-template.md).

## Scenario

You run a platform for **40 teams** on a shared Kubernetes cluster. The platform
operates Argo CD (GitOps delivery), a shared Prometheus + Grafana + Loki + Tempo stack,
and External Secrets Operator. App teams deploy their own services through your golden
paths. Design how the platform observes itself and the substrate — not how any single
app team observes its service.

## Steps

1. **Classify ownership.** In Part A of
   [`observability-strategy-worksheet.md`](./observability-strategy-worksheet.md),
   sort a list of signals into **platform-owned**, **shared/published**, or
   **app-team-owned**. For each, answer the deciding question: *whose 3am is this?*

2. **Define platform-service golden signals.** In Part B, for Argo CD, Prometheus,
   Grafana, and ESO, write the one or two signals you would track (RED / four golden
   signals) and the failure each one catches.

3. **Add the control plane.** In Part C, list the cluster-level signals (API server,
   etcd, nodes, scheduler, capacity) and why each is a platform responsibility rather
   than an app team's.

4. **Fill the SLO catalog.** Transfer your most important services into
   [`platform-slo-catalog.md`](./platform-slo-catalog.md): for each, record the SLI,
   the SLO target, the error-budget consequence, who gets paged, and the runbook link.
   Aim for a *handful* of meaningful SLOs, not dozens.

5. **Design the paging policy.** In Part D of the worksheet, build the routing table:
   for each alert, decide **page vs ticket**, **which on-call** it routes to (by
   ownership label), and the grouping/silence rules that protect the on-call from noise.

6. **Write one runbook.** Pick your highest-stakes alert (likely Argo CD availability or
   API server latency) and complete [`runbook-template.md`](./runbook-template.md):
   what it means, how to confirm, first mitigations, and escalation. Save it as
   `runbook-<name>.md`.

7. **Name the worst single outage.** In Part E, identify the one platform-service
   failure that would hurt the most teams, and justify the SLO you set for it.

## Expected result

A completed strategy in which:

- Part A cleanly separates platform / shared / app ownership with a reason each.
- Parts B–C list golden signals for every core platform service and the control plane.
- The SLO catalog has a few well-chosen SLOs, each with an owner, a page target, and a
  runbook link.
- Part D routes every alert by ownership and tiers page vs ticket.
- One complete runbook exists, and Part E names and justifies the worst-case outage.

Someone who did not write it could read your strategy and know *what the platform
watches, who gets paged, and where to look when it breaks*.

## Cleanup

> This lab creates no infrastructure, so there is nothing to tear down. **Keep** the
> completed worksheet, SLO catalog, and runbook — they are the design inputs for
> Project 3 and strong portfolio artifacts.

```bash
echo "no infrastructure created — keep your strategy documents for Project 3"
```

## Reflection

- Where exactly did you draw the line between "the platform owns this signal" and "the
  app team does"? Which signals were genuinely ambiguous, and how did "whose 3am is
  this?" help?
- How many of your alerts page versus ticket? If most of them page, what would that do
  to your on-call team over a month?
- Every alert links to a runbook. What is the cost of writing them, versus the cost of a
  3am page with no next step?

## Stretch goals (optional)

- Turn one SLO-catalog row into a real Sloth `PrometheusServiceLevel` (Module 11.7) and
  generate its alerts.
- Sketch the **Platform Overview v2** dashboard (Module 11.6) that would surface your
  top platform signals, including GitOps sync health.
- Write a second runbook for a *cluster-level* alert (etcd or API server) and compare
  how its mitigations differ from an application-level one.
