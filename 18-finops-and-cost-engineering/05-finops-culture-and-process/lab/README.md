# Lab — Design your FinOps operating model

> You'll turn the mechanics of this phase into a one-page **operating model**: where
> your team sits in the FinOps lifecycle, a **unit-economics** metric, an
> **anomaly-alert** threshold and routing, a **review cadence**, and three
> **governance guardrails**. Optionally, you'll load a real **cost-anomaly alerting
> rule** into Prometheus and watch it evaluate.

**Estimated time:** ~40–60 minutes
**Type:** Design (worksheet) with an optional build
**Deliverable:** A completed
[`finops-process-worksheet.md`](./finops-process-worksheet.md) defining how your team
operates cost — and, optionally, a cost alert loaded into Prometheus.

## Objectives

- Articulate a FinOps operating model: measure, review, alert, govern.
- Compute a unit-economics metric and judge whether cost is "good" or "bad."
- Encode a cost anomaly as an alerting rule (optional).

## Prerequisites

- [Module 18.5](../README.md) theory — the lifecycle, unit economics, the triangle.
- The worksheet: [`finops-process-worksheet.md`](./finops-process-worksheet.md).
- Optional build: the Module 18.2 Prometheus/OpenCost stack still running, plus the
  starter [`cost-anomaly-alert.yaml`](./cost-anomaly-alert.yaml).

## Steps

1. **Copy the worksheet.** Work in a copy:

   ```bash
   cp finops-process-worksheet.md my-finops-model.md
   ```

2. **Place your team in the lifecycle.** Decide Crawl / Walk / Run, list what's already
   in place from Modules 18.1–18.4, and name the *single next practice* to adopt.
   Honesty here beats ambition — most teams are at Crawl.

3. **Define a unit-economics metric.** Pick a service and its natural business
   denominator (per 1,000 requests, per active user, per order…). Compute the current
   unit cost from a cost figure and a business count:

   ```bash
   # cost per 1,000 requests — swap in your own numbers
   echo "scale=4; 1420.00 / (71000000 / 1000)" | bc -l     # → 0.0200
   ```

   Then answer the question that matters: is this **good cost** (scales with value) or
   **bad cost** (scales with waste)?

4. **Set an anomaly alert.** Choose the signal (cluster, per-team, or unit cost), a
   threshold (e.g. >20% week-over-week), an evaluation window, and — crucially — **who it
   routes to**. Attribution (Module 18.3) is what makes routing to the owning team
   possible.

5. **Pick a review cadence.** Fill the weekly / monthly / quarterly rows: what's reviewed
   and who attends. Tie the monthly review to SLOs so cost sits beside reliability.

6. **Define three governance guardrails.** Map each to a concrete mechanism you've
   already met — the Kyverno label policy (18.3), LimitRange/ResourceQuota (03.7), and an
   approved instance-type list. Guardrails, not gates.

7. **Fill in the triangle.** Place two real workloads and state which corner each
   sacrifices on purpose, and why. If you can't justify the trade, that's a design gap to
   fix.

8. **(Optional build) load the anomaly rule into Prometheus.** If the Module 18.2 stack
   is still up:

   ```bash
   helm upgrade prometheus prometheus-community/prometheus -n prometheus-system \
     -f cost-anomaly-alert.yaml --reuse-values
   kubectl -n prometheus-system rollout status deploy/prometheus-server
   kubectl -n prometheus-system port-forward svc/prometheus-server 9091:80 >/dev/null 2>&1 &
   # browse http://localhost:9091 → Alerts, and look for the cost-anomalies group
   ```

   The `ClusterHourlyCostHigh` demo alert can fire on the lab cluster; the
   `ClusterCostSpikeWoW` rule needs a week of history, so it stays green here — that's the
   production pattern to keep.

## Expected result

A completed `my-finops-model.md` that, on one page, states how your team *operates* cost:
its maturity and next step, a unit-cost metric with a good/bad verdict, an anomaly alert
with an owner, a review cadence, three guardrails mapped to tools, and two workloads
placed on the triangle. Optionally, Prometheus shows your `cost-anomalies` alert group
evaluating.

This is the artifact a platform team actually maintains — the "Operate" phase made
concrete.

## Cleanup

> The worksheet creates **no cloud resources**. Only the optional build touches a
> cluster.

```bash
# stop the optional port-forward if you started it
jobs -p | xargs -r kill
# if you did the optional build and are done with the 18.2 stack, tear it down:
helm uninstall prometheus -n prometheus-system 2>/dev/null || true
kind delete cluster --name pe-finops 2>/dev/null || true
# optional: remove your working copy
rm -f my-finops-model.md
```

Keep the completed worksheet in your portfolio — with the cost model (18.1) it bookends
the phase: one models cost before you spend, the other governs it forever after.

## Reflection

- Which single number on your worksheet would you put in front of leadership, and why is
  it more persuasive than the raw monthly bill?
- Your anomaly alert routes to a team. What had to be true in Modules 18.1–18.3 for that
  routing to even be possible?
- Look at your three guardrails. Which is most likely to make a team route *around* the
  platform, and how would you add an escape hatch so it doesn't?

## Stretch goals (optional)

- Add a second unit-economics metric for a different service and compare their trends —
  which is getting more efficient as it grows?
- Rewrite `cost-anomaly-alert.yaml` as a Prometheus Operator **PrometheusRule** custom
  resource (same `groups`, different wrapper) for an operator-based cluster.
- Draft the actual one-paragraph message you'd send an engineering manager whose service's
  **cost per request** rose 30% after a deploy — practice the FinOps conversation from
  Module 18.3.
