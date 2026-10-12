# Lab — Design a global front door

> A **design lab**, not a build — a real global anycast load balancer costs money and needs
> multiple regions, which is exactly where hands-on practice stops paying off. For a global
> SaaS scenario you'll choose **active-active or active-passive** (justified by the data),
> design the **routing** and **health-based failover**, decide what belongs at the **edge**,
> and write a short **failover runbook** with a game-day test. The deliverable is a design an
> on-call team could actually operate.

**Estimated time:** ~45–60 minutes
**Type:** Design
**Deliverable:** A completed [`global-lb-design-worksheet.md`](./global-lb-design-worksheet.md)
with a chosen topology, routing and health policy, and a failover runbook.

## Objectives

- Choose active-active vs active-passive and justify it **from the data**, with RTO/RPO.
- Design global routing (latency/geo, anycast vs DNS) and automatic health failover.
- Specify deep health checks and a tested failover procedure.
- Decide, deliberately, what (if anything) runs at the edge.

## Prerequisites

- [Module 19.1 · Multi-Cluster Architecture](../../01-multi-cluster-architecture/) for the
  multi-region substrate, and [Phase 13 · Platform SRE](../../../17-platform-sre/) for
  SLO/RTO/RPO thinking.
- No cloud accounts and no tools required — this is a design exercise in Markdown.
- Starter files: [`global-lb-design-worksheet.md`](./global-lb-design-worksheet.md) and
  [`routing-policy.illustrative.yaml`](./routing-policy.illustrative.yaml).

## Steps

1. **Read the illustrative routing policy.** Open
   [`routing-policy.illustrative.yaml`](./routing-policy.illustrative.yaml). It shows the
   provider-agnostic *shape* of a global routing policy — regions, priorities, a health
   check path, and the active-active vs active-passive difference expressed as equal vs
   tiered priorities. You will produce your own version of this in the worksheet.

2. **Fix the scenario.** In the worksheet, record the scenario: a SaaS with users in the EU
   and US, a stated read/write mix, and target **RTO** and **RPO**. Use the default scenario
   or adapt it to a system you know.

3. **Choose the data model — first.** Decide active-active or active-passive, and write the
   one-sentence justification **from the data** (can writes land in two regions at once, and
   must they?). Everything else follows from this; do not skip ahead to routing.

4. **Design the routing.** Choose latency or geo routing, and anycast vs DNS. If DNS, pick a
   TTL and say how it bounds failover. Fill the per-region table (backend, priority, health
   path).

5. **Specify health checks and failover.** Define a **deep** health check (what must be true
   for a region to be "healthy"), the failure thresholds, and what happens automatically when
   a region goes unhealthy. State the expected RTO and the RPO exposure.

6. **Decide the edge.** List what — if anything — you put at the edge (auth, caching, A/B,
   redirects) and explicitly note what you keep *out* of it. "Nothing at the edge" is a valid,
   defensible answer.

7. **Write the failover runbook and a game day.** In the worksheet, write the short procedure
   an on-call engineer follows (or verifies, if automatic) when a region fails, and describe a
   game-day test that fails a region on purpose and measures real RTO/RPO.

## Expected result

A completed `global-lb-design-worksheet.md` in which:

- the data model is chosen first and justified from the data, with RTO/RPO targets,
- routing (latency/geo, anycast/DNS, TTL) and a per-region table are specified,
- a deep health check and automatic failover behaviour are defined,
- the edge scope is deliberate (including "nothing"), and
- a failover runbook and a game-day test are written.

You should be able to defend why losing a whole region is, for your design, a routing event
rather than an outage — and name the one thing most likely to break on first real failover.

## Cleanup

> This lab creates **no cloud resources** — it is a design on paper. Nothing to tear down.

```bash
# No infrastructure was provisioned. If you sketched anything on a kind cluster, delete it:
# kind delete cluster --name gslb-sketch
```

## Reflection

- You chose a data model first. How did that choice constrain everything above it — routing,
  health, RTO/RPO — and would a different data model have made the rest easier or harder?
- Your game day fails a region. Name the single thing most likely to fail the first time, and
  how you would find it before an incident does.
- You decided what lives at the edge. For one thing you kept *out* of the edge, what tempted
  you to put it there, and why was resisting it correct?

## Stretch goals (optional)

- Add a third region (e.g. APAC) and redo the routing table and data model — does
  active-active still hold, and what happens to cross-region write latency?
- Turn your failover runbook into an actual game-day plan with steps, roles, success criteria,
  and rollback.
- Model the monthly cost of your design (standby capacity vs double-serving plus cross-region
  data) and compare it against the availability it buys (tie back to Phase 14).
- Record the design as an ADR using the repo's ADR template so the trade-offs are captured for
  the next engineer.
