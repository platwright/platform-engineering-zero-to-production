# 20 · Advanced Platform Topics

> You have spent nineteen phases building the hard, technical substance of a
> platform — containers, Kubernetes, IaC, GitOps, observability, security, SRE,
> FinOps, multi-cluster. This phase steps back up to the altitude of
> [Phase 1](../01-platform-foundations/) and asks the questions that decide whether
> all of that engineering actually *lands*: **How good is our platform, really?
> Where should it go next? How do we prove its value, and how do we build a team
> and a culture that keeps earning adoption?** This is the reflective, organizational
> capstone of the course — the "soft" side that makes the technical side matter.

**Phase 16 · 4 modules · ~6–10 hours**

> This phase is deliberately **conceptual and organizational**. There is almost
> nothing to install and no cloud spend. The labs are the kind of real work a
> platform lead actually does — a maturity self-assessment, a metrics definition, an
> AI-capability design, an evangelism plan — and they produce artifacts you keep.

## Why this phase matters

A platform can be technically excellent and still fail. Phase 1 told you *why*
(you can build the wrong thing, beautifully) and gave you the lenses — product
thinking, developer experience, team topology. Every phase since then gave you the
*means* to build the right thing well. This phase **closes the loop**: it takes the
foundations you started with and turns them into the instruments a mature platform
organization runs on.

The thread is continuous:

- The **maturity model** (Module 20.1) operationalizes the *whole course*. Each
  level is a checkpoint built from capabilities you already learned to build —
  self-service (Phase 15), GitOps (Phase 8), observability-as-a-service (Phase 11),
  policy enforcement (Phase 13), cost attribution (Phase 18). It tells you where you
  are and what to do next, so improvement is directed rather than random.
- **AI-assisted platform engineering** (Module 20.2) is the newest frontier of the
  self-service and DX work from [Module 01.3](../01-platform-foundations/03-developer-experience/)
  and Phase 15 — natural-language self-service, AIOps, auto-generated docs and
  runbooks, cost-optimization suggestions — held to a firm, responsible-use stance:
  **AI assists the platform engineer; it does not replace judgment.**
- **Metrics** (Module 20.3) build directly on
  [Module 01.3's](../01-platform-foundations/03-developer-experience/) DORA and SPACE
  and [Module 01.2's](../01-platform-foundations/02-platform-as-a-product/) product
  metrics, turning "measure outcomes, not output" into a concrete metrics set and a
  platform health dashboard.
- **Culture and organization** (Module 20.4) builds on
  [Module 01.2's](../01-platform-foundations/02-platform-as-a-product/) product
  mindset and [Module 01.5's](../01-platform-foundations/05-platform-team-topology/)
  team topology — evangelism, internal marketing, handling resistance, open
  roadmaps, and the platform engineer's career path — so adoption is *earned*, not
  mandated.

```text
   Phase 1 (lenses)                 Phase 16 (instruments)
   ────────────────                 ──────────────────────
   "What is a platform?"      ───▶  Maturity model: where are we, what's next?
   Platform as a product      ───▶  Metrics: prove outcomes; health dashboard
   Developer experience       ───▶  AI-assisted DX; SPACE/DORA in practice
   Team topology              ───▶  Culture: evangelism, resistance, careers

   The course is a loop, not a line: you end where you began, with evidence.
```

Finish this phase and you will not only be able to *build* a platform — you will be
able to **assess it, measure it, evolve it, and lead the team and culture around
it.** Those are the capabilities that separate a senior platform engineer from a
principal one, and they are exactly what the [capstone projects](../21-capstone-projects/)
ask you to demonstrate.

## Visual references

- [Platform maturity model](../diagrams/platform/platform-maturity-model.png)
- [SLO burn rate](../diagrams/platform/slo-burn-rate.png)

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 96 | [Platform Engineering Maturity Model](./01-platform-engineering-maturity-model/) | The five levels (Reactive Ops → Adaptive Platform); the dimensions behind them; how to assess honestly and prioritize the next step. | A completed maturity self-assessment with a current-level rating and a next-step plan. |
| 97 | [AI-Assisted Platform Engineering](./02-ai-assisted-platform-engineering/) | LLM self-service, AIOps, AI docs/runbooks, AI cost optimization; and the responsible-use stance that keeps a human in the loop. | A one-page design canvas for one AI-assisted platform capability, with guardrails. |
| 98 | [Platform Engineering Metrics](./03-platform-engineering-metrics/) | DORA in the platform context, SPACE for DX, adoption metrics, and a platform health dashboard. | A metrics-definition worksheet plus a sketched health dashboard (Grafana JSON provided). |
| 99 | [Platform Engineering Culture and Organization](./04-platform-engineering-culture/) | Product mindset, avoiding the "platform empire," evangelism, internal marketing, handling resistance, open roadmaps, and careers. | A platform evangelism / communication plan (or a worked resistance-scenario response). |

Work them in order — each builds on the last, and all four build on Phase 1.
Together they take you from "we built a platform" to "we know exactly how good it
is, where it's going, how we'll prove it, and how we'll bring people with us."

## Learning objectives

By the end of this phase you will be able to:

- Place a platform on a **five-level maturity model** across several dimensions, and
  turn the assessment into a prioritized, evidence-based improvement plan.
- Identify where **AI can responsibly assist** platform work — self-service, AIOps,
  documentation, cost — and design a capability that keeps a human accountable for
  judgment.
- Define a **platform metrics set** grounded in DORA, SPACE, and adoption, and
  design a **platform health dashboard** that drives decisions rather than vanity.
- Build the **culture and organization** around a platform: evangelism, internal
  marketing, open roadmaps, handling resistance, and a platform-engineering career
  ladder — so adoption is earned.

## Prerequisites

This phase is **concept and leadership** work, so the prerequisites are mostly
conceptual rather than tools:

- [Phase 1 · Platform Foundations](../01-platform-foundations/) — especially
  [01.2 Platform as a Product](../01-platform-foundations/02-platform-as-a-product/),
  [01.3 Developer Experience](../01-platform-foundations/03-developer-experience/),
  and [01.5 Platform Team Topology](../01-platform-foundations/05-platform-team-topology/).
  This phase is the other end of the loop those modules opened.
- A working familiarity with the technical phases (Kubernetes, GitOps, observability,
  security, SRE, FinOps). You do not need to have *completed* every lab, but the
  maturity model and metrics assume you recognize the capabilities they reference.
- No installs are required for the core path. The metrics lab *optionally* imports a
  provided Grafana dashboard JSON if you still have the Grafana from
  [Project 3](../12-platform-project-03/) running; a paper sketch is a first-class
  alternative.

## A note on the labs

Like the Phase 1 labs, these produce **portfolio artifacts** — the maturity
assessment, metrics definition, AI-capability canvas, and evangelism plan are exactly
the documents a platform lead writes to set direction and win support. Keep them.
They are also excellent raw material for the [capstone projects](../21-capstone-projects/),
where you present a platform as a product, with evidence.

---

Start with [**96 · Platform Engineering Maturity Model →**](./01-platform-engineering-maturity-model/)
