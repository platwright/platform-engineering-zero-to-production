# Lab — Mesh or no mesh? A decision memo

> A service mesh is one of the most over-adopted technologies in platform engineering.
> This lab practices the skill that matters most: deciding — rigorously — **whether to
> adopt one at all**, which one, and why, defending the choice against the lighter
> alternatives (Cilium, Gateway API, OpenTelemetry). The deliverable is a one-page
> decision memo, the artifact a real platform team writes before taking on a mesh.

**Estimated time:** ~45–60 minutes
**Type:** Design / decision
**Deliverable:** A completed [decision memo](./decision-memo-template.md) for a given
scenario, with a clear recommendation and justification.

## Objectives

- Separate the *capabilities needed* from the *tool* (mesh vs lighter options).
- Map each requirement to the lightest tool that satisfies it.
- Make and defend an adopt / don't-adopt recommendation.

## Steps

1. **Pick a scenario** — one of the three below, or a real system you know.

2. **List the actual requirements.** For the scenario, write down the concrete needs:
   encryption in transit? which traffic-management features (retries, circuit breaking,
   canary, mirroring, fault injection)? what observability? at what scale (how many
   services, how many teams)? what's the team's operational maturity?

3. **Map each requirement to the lightest tool** that satisfies it, using the course
   stack:
   - mTLS between services → **Cilium** (Module 14.4) often suffices.
   - Ingress + weighted canary → **Gateway API** (Module 14.5).
   - Per-service metrics/traces → **OpenTelemetry** (Project 3).
   - Rich resilience (circuit breaking, fault injection, mirroring) + uniform L7
     telemetry across a large fleet without app changes → a **mesh** (Istio).

4. **Decide.** Is there a residual need that *only* a mesh meets? If yes, recommend a
   mesh (and specify **ambient** vs sidecar, and incremental rollout). If no, recommend
   the lighter combination and explicitly say "no mesh."

5. **Write the memo** using [the template](./decision-memo-template.md): context,
   requirements, options considered, recommendation, risks, and what would change the
   decision.

6. **Stress-test it.** Hand your memo (or read it as) a skeptic: could they adopt a
   cheaper option and still meet the requirements? If so, revise.

## Expected result

A one-page decision memo with a defensible recommendation, each requirement mapped to a
tool, and the main risks named. A reader should understand *why* — not just *what* —
you chose.

## Scenarios

> **A. The small platform (8 services, 2 teams).** Wants encryption between services and
> slightly nicer canary deploys. Already runs Cilium + the Gateway API.

> **B. The regulated fleet (120 services, 15 teams).** Must prove mTLS everywhere for
> compliance, needs circuit breaking and fault-injection testing, and wants uniform L7
> metrics without instrumenting 120 apps. Mature platform team.

> **C. The migrating monolith-to-microservices org (growing fast, ~30 services).**
> Needs progressive delivery and resilience patterns, apps are partly instrumented with
> OTel, team is still learning Kubernetes.

## Reflection

- For your scenario, how many requirements were met by Cilium/Gateway API/OTel *before*
  a mesh was even needed? What does that tell you about mesh adoption in general?
- If you recommended a mesh, what's the single biggest operational risk, and how would
  you de-risk the rollout?
- If you recommended *against* a mesh, what specific future requirement would flip your
  decision?

## Stretch goals (optional)

- Write the memo for a *second* scenario and compare how the recommendation changes with
  scale and maturity.
- Sketch an incremental Istio **ambient** adoption plan for Scenario B: which namespace
  first, what you'd measure, and the rollback criteria.
