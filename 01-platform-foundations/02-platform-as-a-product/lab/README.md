# Lab — Platform Product Brief

> Turn evidenced developer pain into a crisp, one-page plan. The Platform Product
> Brief is the single most useful artifact for aligning a platform team before any
> code is written — and a great portfolio piece.

**Estimated time:** ~45–60 minutes
**Type:** Design
**Deliverable:** A completed one-page [Platform Product Brief](./platform-product-brief-template.md).

## Objectives

- Convert discovery findings into a sharp problem statement and persona.
- Express what developers are "hiring" the platform for as Jobs to be Done.
- Scope a **thin** first release (three capabilities) with explicit anti-goals.
- Choose success metrics you could actually measure.

## Prerequisites

- Your findings from the [Module 01.1 lab](../../01-what-is-platform-engineering/lab/README.md).
  No findings of your own? Use the solo-option personas (Priya, Marco, Aisha) from
  that lab.

## Steps

1. **Start from the biggest opportunity** you identified in 01.1. That becomes your
   **problem statement** — one or two sentences of *real, evidenced* pain. Resist
   the urge to describe a solution here.

2. **Name a narrow target persona.** Who specifically is this for? "All engineers"
   is too broad to design for. Prefer "backend engineers standing up a *new*
   service" or "on-call engineers debugging an *unfamiliar* service."

3. **Write 2–4 Jobs to be Done**, each in the form:

   > *When `<situation>`, I want to `<motivation>`, so I can `<outcome>`.*

   None of them should name a tool.

4. **Choose exactly three initial capabilities** — the *smallest* set that serves
   those jobs (TVP discipline). If you're tempted to list six, you haven't been
   ruthless enough. For each, note build / buy / adopt.

5. **Define success metrics.** Pick 2–3 you could really measure (adoption %,
   time-to-first-deploy, a DORA metric, NPS). State a rough target.

6. **Write the anti-goals.** List 3–5 things this platform will deliberately **not**
   do (for now). This is the hardest and most valuable part.

7. **Pressure-test it.** Read it back and ask: *Would my persona actually choose
   this over what they do today? Is it thin enough to ship in weeks, not quarters?*

## Expected result

A single-page brief (use [the template](./platform-product-brief-template.md)) that
a new team member could read in two minutes and understand *who* it's for, *what*
problem it solves, *what* you'll build first, *how* you'll measure it, and *what*
it won't do.

## Cleanup

> Nothing to tear down ? this is a design/discovery lab that creates no cloud or
> cluster resources. Keep your completed deliverable; it's a portfolio artifact.

## Reflection

- Did writing the **anti-goals** change your capability list? (It usually should.)
- Are your capabilities *opinions and glue* (good to build) or *commodities* (better
  to buy)?
- Could you defend every item with a sentence that starts "developers told us…"?

## Stretch goals (optional)

- Sketch a **developer journey map** for your persona's current path to production,
  and mark where your three capabilities intervene.
- Draft a three-milestone roadmap: what's v1 (this brief), what's v2, what's "later."

---

## Worked example (solo option)

Using Priya/Marco/Aisha from Module 01.1, here's a filled brief you can model
yours on. Yours will differ — that's fine.

> **Problem statement.** New and existing backend teams lose days standing up and
> safely shipping services: there's no agreed "right way," no feedback that a deploy
> is healthy, and routine access/resources require waiting on humans. New hires take
> ~9 days to their first production change.
>
> **Target persona.** A backend engineer creating or operating a service on an
> established team — especially in their first weeks, or when standing up something
> new.
>
> **Jobs to be done.**
>
> - *When I start a new service, I want a known-good, secure starting point, so I can
>   ship features instead of assembling boilerplate.*
> - *When I deploy, I want immediate confirmation that it's healthy, so I don't learn
>   about failures from customers.*
> - *When I need routine access or resources, I want to get them myself, so I'm not
>   blocked waiting on another team.*
>
> **Initial capabilities (thin v1).**
>
> 1. A **golden-path service template** (secure Dockerfile, sane manifest defaults,
>    CI wired) — *build* (our opinion/glue).
> 2. **Deploy health feedback**: every new service gets a default dashboard + a
>    liveness/readiness check from the template — *build thin on bought* observability.
> 3. **Self-service dev namespace + secrets** via a documented command — *build thin
>    on bought* secret manager.
>
> **Success metrics.**
>
> - Time-to-first-production-deploy for a new service: 9 days → < 1 day.
> - Golden-path adoption: ≥ 60% of new services in 2 quarters.
> - Platform NPS ≥ +20 after 1 quarter.
>
> **Anti-goals (for now).**
>
> - We will **not** support every language — Go and Python templates first.
> - We will **not** manage stateful databases yet.
> - We will **not** replace teams' IDEs or local dev setup.
> - We will **not** require a ticket for anything on the golden path.
> - We will **not** build a custom portal in v1 — a README and a CLI are enough.
