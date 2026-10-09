# Lab — Platform Team Charter

> The capstone of the Foundations phase. A charter makes a platform team's mission,
> scope, support promises, and success metrics explicit — the single best defense
> against the gatekeeper trap and scope creep. It also ties together everything you
> produced in Modules 01.1–01.4.

**Estimated time:** ~45–60 minutes
**Type:** Design
**Deliverable:** A completed one-page [Platform Team Charter](./platform-team-charter-template.md).

## Objectives

- Articulate a platform team's mission in terms of *whom it serves* and *what load
  it removes*.
- Define owned capabilities **and** explicit out-of-scope capabilities.
- Commit to a support model, interaction modes, communication rhythm, and
  success metrics defined as *stream-team outcomes*.

## Prerequisites

- Your artifacts from Modules 01.1–01.4 (discovery findings, product brief, DX
  audit, IDP assessment). Or the "HelloCorp" fictional thread used throughout.

## Steps

1. **Write the mission** (one sentence). Whom do you serve, and what cognitive load
   do you remove? Avoid tool names; name the outcome. Example shape: *"We help
   HelloCorp's product teams ship and operate services safely without becoming
   infrastructure experts."*

2. **List owned capabilities.** What you provide *as a service* — map these to the
   five planes and to the capabilities in your Module 01.2 brief / 01.4 assessment.
   Keep it thin for v1.

3. **List out-of-scope capabilities.** The hardest, most valuable section. What will
   you deliberately *not* own (yet)? This protects the team from becoming a
   catch-all.

4. **Define the support model & SLA.** Where do developers get help? What
   reliability do you promise (even a soft one to start)? What's your escalation
   path? (Precise platform SLOs come later in the course — a directional promise is
   fine now.)

5. **State your interaction modes.** Default to X-as-a-Service. Note when you'll
   *collaborate* (building something new with a pilot team) and *facilitate*
   (onboarding), and that those are temporary.

6. **Set the communication rhythm.** Office hours, changelog, roadmap reviews,
   support channel.

7. **Choose success metrics — as stream-team outcomes.** Adoption, time-to-first-
   deploy, DORA for served teams, NPS. *Not* ticket count.

8. **Pressure-test it.** Would this charter stop someone from dumping a random
   responsibility on you? Does it make clear you enable rather than gate? Could a
   stream team read it and know exactly what to expect?

## Expected result

A one-page charter (use [the template](./platform-team-charter-template.md)) a new
team member or a stream-team lead could read in two minutes and understand the
platform team's purpose, scope, promises, and how success is judged.

## Reflection

- Is every success metric a **stream-team outcome** rather than a measure of your own
  activity? If not, revise.
- Does your "out of scope" list genuinely constrain you, or is it mush?
- Which interaction mode are you in *today* with most teams — and is it where you
  want to be a year from now?

## Stretch goals (optional)

- Add a short **RACI** or ownership note for your top 3 capabilities.
- Draft the **first changelog entry** and a **first office-hours agenda** — the
  smallest step toward communicating like a product team.

---

## Worked example (abridged)

A thin charter for the HelloCorp platform team:

> **Mission.** We help HelloCorp's product teams ship and operate services safely and
> quickly, without each team having to become a Kubernetes, cloud, or CI/CD expert.
>
> **Capabilities we own (v1).** A golden-path service template (secure defaults, CI,
> default dashboard); self-service dev namespaces and secrets; a supported deployment
> pipeline; baseline observability wired in by default.
>
> **Out of scope (for now).** Stateful database administration; bespoke per-team
> pipelines; application-level code; non-Go/Python stacks; a custom portal.
>
> **Support model / SLA.** `#platform-support` Slack (best-effort same-day); weekly
> office hours; the golden path targets 99.9% pipeline availability (directional).
> Escalation: on-call platform engineer for prod-blocking issues.
>
> **Interaction modes.** Default **X-as-a-Service** (teams self-serve the golden
> path). **Collaborate** with one pilot team to build each new capability.
> **Facilitate** onboarding for a team's first two weeks, then step back.
>
> **Communication.** Weekly office hours; changelog in the platform repo; monthly
> public roadmap review open to all engineers.
>
> **Success metrics (stream-team outcomes).** Golden-path adoption ≥ 60% of new
> services in 2 quarters; time-to-first-prod-deploy 9 days → < 1 day; served teams'
> deployment frequency up and change-failure rate flat-or-down; platform NPS ≥ +20.
