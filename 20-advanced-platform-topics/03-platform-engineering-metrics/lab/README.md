# Lab — Define a Platform Metrics Set and Health Dashboard

> Define a small, balanced platform metrics set — DORA, SPACE, and adoption — with
> sources, cadences, targets, and paired guardrails, then sketch the four-panel health
> dashboard. Import the provided Grafana JSON, or draw it on paper.

**Estimated time:** ~45–70 minutes
**Type:** Design
**Deliverable:** A completed [metrics-definition worksheet](./metrics-definition-worksheet.md) plus a health-dashboard sketch (import [`platform-health-dashboard.json`](./platform-health-dashboard.json) into Grafana, or sketch the four panels).

## Objectives

- Choose 6–8 metrics spanning all three lenses (delivery, experience, adoption).
- Define each unambiguously: what, source, cadence, target, and a **paired guardrail**.
- Record a **baseline** for each (even a rough one) so impact is provable later.
- Lay out the **four-panel** platform health dashboard.

## Prerequisites

- [Module 20.3 theory](../README.md) — the three lenses, DORA's two directions, SPACE,
  adoption, and the four-panel dashboard.
- Helpful: [Module 01.3 Developer Experience](../../../01-platform-foundations/03-developer-experience/)
  (DORA/SPACE) and [Module 01.2](../../../01-platform-foundations/02-platform-as-a-product/)
  (adoption as north star).
- **Optional** for the import step: a running Grafana (e.g. from
  [Project 3](../../../12-platform-project-03/)). Not required — a paper sketch is a
  first-class deliverable.

## Steps

1. **Copy the worksheet.** Open
   [`metrics-definition-worksheet.md`](./metrics-definition-worksheet.md) and copy it
   to a working file.

2. **Write the goal first (GQM).** State the platform goal in one sentence, then the
   questions you need numbers to answer. Metrics come *last*, derived from questions —
   not a grab-bag of whatever is easy to collect.

3. **Pick one or two metrics per lens.** Delivery (DORA — pick the direction that
   matters most and say which), Experience (SPACE — at least a Satisfaction metric),
   Adoption (at least the golden-path headline). Keep the total to 6–8.

4. **Define each metric fully.** For every metric fill: what it is, source, cadence,
   target, and its **paired guardrail** — the metric you must not wreck while
   improving it (speed ↔ safety, adoption ↔ satisfaction). A metric without a
   guardrail is a future own-goal.

5. **Record a baseline.** Put today's value (or `unknown — will capture by <date>`)
   in every row. This is the single most valuable column for proving impact later.

6. **Check for the two traps.** Confirm no metric is an **individual**-productivity
   count, and no target can be hit by **mandating** adoption at the expense of
   satisfaction. Fix any that fail.

7. **Lay out the dashboard.** Either import
   [`platform-health-dashboard.json`](./platform-health-dashboard.json) into Grafana
   (Dashboards → New → Import → paste JSON) and map its placeholder queries to your
   real metrics, or sketch the four panels — ① platform SLO status, ② active
   incidents, ③ change activity (DORA), ④ DX trend — on paper. Note which panels are
   real-time and which are trend.

8. **Attach a decision to the dashboard.** Name the recurring review (weekly/monthly)
   where these numbers will actually change a choice. A dashboard with no ritual is
   theater.

## Expected result

- A worksheet with 6–8 metrics across all three lenses, each with source, cadence,
  target, **paired guardrail**, and a baseline.
- A four-panel health-dashboard sketch (imported or drawn), with real-time vs trend
  noted.
- A named review ritual where the dashboard drives a decision.

Someone could pick up your worksheet and start collecting the exact numbers tomorrow —
no ambiguity about what, from where, how often, or what "good" means.

## Cleanup

> If you imported the dashboard into a throwaway Grafana (e.g. a local Project 3
> stack), you can delete the dashboard from the Grafana UI. Otherwise there is
> **nothing to tear down** — this is a design lab with no cloud spend. Keep the
> worksheet; it's a portfolio artifact.

## Reflection

- Which lens were you weakest on — did you reach for easy delivery/activity numbers
  and under-serve **satisfaction** and **adoption depth**?
- For each metric, can you name the **decision** it will change? If not, why is it on
  the dashboard?
- Did any target tempt you toward a behavior you'd regret (mandating adoption, chasing
  deploy counts)? Did the paired guardrail catch it?

## Stretch goals (optional)

- **Wire one metric for real.** If you have Project 3's Prometheus/Grafana, implement
  one panel end to end (e.g. deployment frequency from your GitOps history).
- **Design the DX survey.** Draft the 5-question quarterly survey behind your
  Satisfaction metric, including the NPS question and one open-text prompt.
- **Connect to maturity.** Map each adoption metric to a maturity level
  (Module 20.1) and mark which level your current numbers put you at.
