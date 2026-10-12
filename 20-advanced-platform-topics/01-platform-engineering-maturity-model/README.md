# Module 20.1 — Platform Engineering Maturity Model

> A maturity model is a mirror. It lets you answer three questions honestly:
> *where is our platform today, where should it go next, and what is the single most
> valuable thing to improve?* This module gives you a five-level model — Reactive Ops
> to Adaptive Platform — plus the dimensions beneath it, so improvement becomes
> **directed** instead of a scatter of disconnected projects. It operationalizes the
> entire course: every level is built from capabilities you have already learned to
> build.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 1 · Platform Foundations](../../01-platform-foundations/) (the lenses), and a working familiarity with the technical phases (self-service, GitOps, observability, policy, cost). No tools, no cloud.

## Learning objectives

By the end of this module you will be able to:

- Describe the **five maturity levels** (Reactive Ops → Adaptive Platform) and the
  signal that distinguishes each from the one below it.
- Assess a platform across **multiple dimensions**, not a single score, and explain
  why a single number hides more than it reveals.
- Use **time-to-environment** and **developer satisfaction** as level-defining
  indicators without treating them as the whole picture.
- Turn an assessment into a **prioritized, evidence-based next-step plan** — the one
  improvement that moves the most load.
- Relate the model to the **CNCF Platform Engineering Maturity Model** and know when
  a richer, multi-dimensional framework is worth the extra effort.

---

## 1. Concept

### What a maturity model is (and is not)

A **maturity model** is a ladder of recognizable stages a capability passes through
as it improves, with observable signals for each stage. Used well, it is a
*diagnostic and planning tool*: it tells you where you are and suggests the next
rung. Used badly, it becomes a vanity scoreboard — a number teams chase for its own
sake, or a stick leadership uses to shame.

The point is never "reach Level 5." Most platforms should not be Level 5, and some
organizations get everything they need at Level 3. The point is to **make the
current state legible** and to **pick the next improvement deliberately**.

### The five levels

This course uses a five-level model. Read each level by its *defining signal* — the
one thing that is true here and was not true below.

```text
Level 1 — REACTIVE OPS
  Manual provisioning; runbooks live in people's heads.
  No self-service; ticket-driven everything.
  Defining signal: time-to-environment > 1 week.

Level 2 — STANDARDIZED DEVOPS
  Standard CI/CD pipelines; infrastructure as code; basic monitoring.
  The "right way" exists and is written down, even if humans still run it.
  Defining signal: time-to-environment < 1 day.

Level 3 — SELF-SERVICE PLATFORM
  Developers self-serve common tasks; GitOps delivers config;
  observability is a platform service. Golden paths exist — adoption is partial.
  Defining signal: time-to-environment < 1 hour.

Level 4 — PRODUCTIZED PLATFORM
  An IDP with catalog, templates, and docs; the platform has SLOs and on-call;
  security is enforced BY THE PLATFORM, not by code review.
  Adoption > 80% of teams on golden paths.
  Defining signal: time-to-environment < 10 minutes.

Level 5 — ADAPTIVE PLATFORM
  The platform self-heals and self-optimizes; AI-assisted developer experience;
  continuous quality improvement via feedback loops; full cost attribution and
  optimization automation.
  Defining signal: developer satisfaction score > 4/5, consistently.
```

Notice the shape of the climb. Levels 1→2 are about **standardization** (a right way
exists). Levels 2→3 are about **self-service** (humans leave the critical path).
Levels 3→4 are about **product** (adoption, SLOs, enforcement by the platform).
Levels 4→5 are about **adaptation** (the platform improves itself, with feedback and
AI assistance). This is the arc of the whole course, compressed into five rungs.

### It is not one number — it is several dimensions

A platform is rarely at the same level everywhere. You might have Level 4 CI/CD and
Level 1 cost visibility. A single score would average those into a meaningless "2.5."
Assess **per dimension** instead. A practical set, each traceable to a phase of this
course:

```text
Dimension            Phase it draws on        "What good looks like" climbs toward…
─────────────        ─────────────────        ─────────────────────────────────────
Self-service         15 (DX & IDP)            devs provision without a human
Delivery (CI/CD)     06, 08 (CI/CD, GitOps)   PR-to-prod is automated & safe
Observability        11 (Observability)       o11y is a default, not a project
Security & policy    13 (Security/Policy)     enforced by the platform, not review
Reliability (SRE)    17 (Platform SRE)        SLOs, error budgets, on-call for the platform
Cost (FinOps)        18 (FinOps)              spend is attributed & optimized by default
Adoption & DX        01.2, 01.3               teams choose the paved road; DX is measured
Organization         01.5 (Team Topology)     enabling, not gatekeeping; product team
```

Each dimension has its own 1–5 climb. The honest assessment is a **profile** — a
small bar chart across dimensions — not a single trophy number.

### The level-defining indicators

Two indicators thread through the ladder and are worth watching closely:

- **Time-to-environment** (how long from "I need a place to run my service" to "it
  exists, safely") drops by an order of magnitude at each level: weeks → a day →
  an hour → ten minutes. It is a ruthless, end-to-end proxy that exposes every
  ticket, wait, and undocumented step — the sibling of the
  *time-to-first-production-deployment* north star from
  [Module 01.3](../../01-platform-foundations/03-developer-experience/).
- **Developer satisfaction** defines the top of the ladder because a platform that
  self-optimizes but developers dislike has missed the point. At Level 5 the signal
  is *sustained* satisfaction — the product mindset from
  [Module 01.2](../../01-platform-foundations/02-platform-as-a-product/) made durable.

---

## 2. Why it matters for platform engineering

Without a maturity model, platform improvement is a stream of disconnected projects
chosen by whoever argued loudest, and you cannot tell a sponsor whether last year's
investment moved anything. The model gives you three things:

- **Direction.** It converts "make the platform better" into "we are Level 2 on
  self-service and Level 1 on cost; the next rung on self-service removes the most
  load, so we do that first." Improvement becomes a sequence, not a scatter.
- **A shared language with leadership.** "We are a Level 3 platform targeting Level 4
  in two quarters, and here is the one capability that gets us there" is a sentence a
  VP can fund. It reframes platform work from cost center to roadmap.
- **A guard against skipping rungs.** You cannot buy your way to Level 5 with an AI
  copilot bolted onto a Level 1 platform. The ladder makes prerequisites explicit:
  you cannot have self-service (L3) without standardization (L2); you cannot productize
  (L4) without self-service (L3). It stops the "tool-first" mistake from Phase 1 at the
  organizational scale.

This is where the course comes full circle. Phase 1 warned that platforms fail by
building the wrong thing. The maturity model is how you keep checking, with evidence,
that you are building the *right next* thing.

---

## 3. Mental model

Hold the ladder in your head as a climb where **each rung removes a human from a
critical path**, and the top rung adds a feedback loop:

```text
        developer satisfaction, sustained      ▲  L5 ADAPTIVE
   self-heals, self-optimizes, AI-assisted     │     platform improves itself
   ───────────────────────────────────────────┤
        adoption > 80%, SLOs, enforced          │  L4 PRODUCTIZED
   catalog + templates + docs; it's a product   │     product, not a project
   ───────────────────────────────────────────┤
        time-to-env < 1 hour                     │  L3 SELF-SERVICE
   golden paths; GitOps; o11y as a service       │     humans leave the hot path
   ───────────────────────────────────────────┤
        time-to-env < 1 day                       │  L2 STANDARDIZED
   CI/CD + IaC + basic monitoring, written down   │     a "right way" exists
   ───────────────────────────────────────────┤
        time-to-env > 1 week                        │  L1 REACTIVE
   manual, ticket-driven, tribal knowledge          │     firefighting
        ────────────────────────────────────────────┴───────────────────────▶
                      each rung: less human in the loop, more earned adoption
```

Two rules to remember a year from now:

- **You climb by demand, not by ambition** — the same Thinnest Viable Platform
  discipline from [Module 01.1](../../01-platform-foundations/01-what-is-platform-engineering/),
  applied to the whole platform. Pull the rung that removes real, observed pain.
- **The profile beats the score.** Report a per-dimension bar chart, pick the lowest
  bar that hurts the most, and move that one.

---

## 4. Minimal implementation

You do not need a tool to assess maturity. The smallest honest implementation is a
table: dimensions down the side, the level you can *defend with evidence* across the
top, and one piece of evidence per cell.

```text
Dimension        L1  L2  L3  L4  L5   Evidence (why this level, not higher)
───────────      ──  ──  ──  ──  ──   ─────────────────────────────────────
Self-service          ██            new namespace still needs a platform-team ticket
Delivery (CI/CD)          ██        PR-to-prod automated; rollback is manual
Observability         ██            dashboards exist but each team builds its own
Security & policy         ██        Kyverno enforces labels; image signing is opt-in
Reliability (SRE)     ██            platform has no SLOs or on-call of its own
Cost (FinOps)     ██                no per-team attribution; nobody owns the bill
Adoption & DX             ██        ~55% on the golden path; no DX survey yet
Organization              ██        mostly self-service, but still some gatekeeping
```

The discipline is in the **evidence column**. "We're Level 3 on self-service" is an
opinion; "a new namespace still requires a platform-team ticket, so we're Level 2"
is a finding. Force every cell to cite something observable — a ticket queue, a
pipeline, a dashboard, an adoption percentage, a survey.

Read the lowest-and-most-painful bar, and that is your next-step plan:

```text
Next step (one thing): cost is Level 1 and causing budget surprises.
  → Deploy OpenCost (Phase 18) and publish a per-team weekly showback report.
  → Target: Cost dimension L1 → L2 in one quarter; revisit the profile after.
```

That is the entire method: **profile → lowest painful bar → one next step →
re-assess.** The lab walks you through it on a real (or provided) platform.

---

## 5. Hands-on lab

You will assess a platform across the eight dimensions, defend each level with
evidence, produce a maturity profile, and write a prioritized next-step plan. Do it
against a platform you know for maximum value; a fully worked fictional scenario is
provided so you can complete it solo.

➡️ **[Start the lab: Platform Maturity Self-Assessment](./lab/README.md)**

---

## 6. Production considerations

- **Assess with the people who feel the pain, not just the platform team.** A
  platform team self-grades generously. Bring in stream-aligned engineers; their
  "it still takes a ticket" beats your "we shipped self-service."
- **Re-assess on a cadence and track the trend.** Maturity drifts both ways — a
  Level 4 capability decays to Level 3 if unmaintained — so re-assess quarterly or
  semi-annually. The *trend* ("self-service L2 → L3, adoption 55% → 78%") matters more
  than the absolute level, and is the before/after story you tell in
  [Module 20.4](../04-platform-engineering-culture/).
- **Tie the model to the roadmap, not to compensation.** The moment a level becomes a
  performance target, people optimize the number and the model stops telling the truth
  (Goodhart's law). Keep it a planning instrument.
- **Different platforms have different right answers.** A ten-engineer startup may be
  well served at Level 2–3; a regulated enterprise may need Level 4 enforcement. "What
  level should we be?" is a business question, not a universal constant.
- **Prerequisites are real.** Do not let a mandate to "add AI" (Level 5) jump the
  queue when self-service (Level 3) is not solid. Sequence honestly; a shaky lower
  rung collapses the ones above it.

## 7. Common mistakes

- **Chasing Level 5 because it's the top.** Adding self-healing and AI to an
  unstandardized, ticket-driven platform. — It skips prerequisites and the shiny
  layer collapses onto a shaky base. — *Fix:* assess honestly, fix the lowest painful
  rung first, and accept that your right answer may be Level 3.
- **Reporting a single averaged score.** "We're a 2.7" averages a Level 4 CI/CD with
  a Level 1 cost practice into a number that hides both. — It erases exactly the
  signal you need. — *Fix:* always report the per-dimension profile.
- **Grading yourself without evidence.** The platform team optimistically marks every
  cell one level high. — Opinions drift up; findings stay honest. — *Fix:* require an
  observable citation per cell, and include stream-team engineers in the assessment.
- **Turning the level into a target or a weapon.** Leadership sets "reach Level 4" as
  an OKR, or shames a team for being Level 2. — People game the number or hide the
  truth. — *Fix:* keep it diagnostic; reward outcomes (adoption, DX, reliability), not
  the label.
- **Assess once, then never again.** A one-time assessment gathers dust while the
  platform regresses. — Maturity is a moving target. — *Fix:* schedule re-assessment
  and track the trend.
- **Confusing tool count with maturity.** "We have Backstage and Argo CD, so we're
  Level 4." — Tools installed ≠ capabilities adopted; a catalog nobody fills is not
  Level 4. — *Fix:* grade on *adopted outcomes* (time-to-env, adoption %), not
  inventory.

## 8. Assessment

**Knowledge checks**

1. Name the five levels and give the defining signal (the indicator) for each.
2. Why assess per dimension instead of reporting one overall maturity score?
3. What prerequisite must be solid before self-healing/AI (Level 5) is worth adding,
   and why?
4. The platform team grades itself Level 4 on self-service; a stream engineer says a
   new namespace still takes a two-day ticket. What is the real level, and what does
   the disagreement reveal about *how* to assess?

**Concept exercise**

> Explain to a new engineering director how good your platform is and what to improve
> next — **without using the words "maturity," "level," or the name of any
> framework.** Describe it in terms of what a developer experiences and what you'll
> change.

**Trade-off / design exercise**

> Your assessment shows: Delivery L4, Self-service L3, Observability L3, Cost L1,
> Reliability L2, Adoption 70%. You have budget for exactly one initiative next
> quarter. Which dimension do you move, and how do you justify the choice over the
> others?

<details>
<summary>Discussion</summary>

- **Q1:** L1 Reactive Ops — time-to-env > 1 week; L2 Standardized DevOps — < 1 day;
  L3 Self-Service — < 1 hour; L4 Productized — < 10 minutes; L5 Adaptive — developer
  satisfaction > 4/5 consistently.
- **Q2:** A platform is at different levels per dimension; averaging hides both the
  strong and the weak capability. The profile tells you *what* to fix; a single score
  tells you nothing actionable.
- **Q3:** Self-service (Level 3) and the standardization beneath it. Self-healing and
  AI assistance operate *on top of* reliable, standardized, self-service plumbing;
  bolt them onto a ticket-driven base and they amplify chaos instead of removing it.
- **Q4:** The real level is ~L2 — the evidence (a two-day ticket) beats the
  self-assessment. The disagreement reveals that assessments must include the people
  who feel the pain and must cite observable evidence, not platform-team optimism.
- **Trade-off:** A strong case is **Cost (L1)** — it is the lowest bar, it is almost
  certainly causing unmanaged spend, and attribution (Phase 18) is a well-understood,
  high-leverage first rung (OpenCost + showback). Reliability (L2) is defensible if
  the platform is causing incidents. The key is to justify with *evidence of pain and
  leverage*, not personal interest — and to pick the lowest painful bar, not the most
  fun project.

</details>

## 9. Further reading

- CNCF TAG App Delivery — [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)
  (the multi-dimensional model: Investment, Adoption, Interfaces, Operations,
  Measurement)
- CNCF TAG App Delivery — [Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
  (what a platform is, as a foundation for the dimensions)
- Matthew Skelton & Manuel Pais — [*Team Topologies*](https://teamtopologies.com/)
  (the organization dimension and cognitive load)
- DORA — [research and the capabilities model](https://dora.dev/) (the delivery
  dimension and its defining capabilities)
- Thoughtworks — [Technology Radar](https://www.thoughtworks.com/radar) (evidence on
  golden paths and platform practices as they mature)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 16 overview](../README.md)
· _Next:_ [20.2 — AI-Assisted Platform Engineering →](../02-ai-assisted-platform-engineering/)
