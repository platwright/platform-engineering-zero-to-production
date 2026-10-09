# Module 01.5 — Platform Team Topology

> A platform can be technically excellent and still fail because the *team* is
> organized wrong — as a gatekeeper everyone waits on, or a help desk that burns
> out. This module applies **Team Topologies** to platform teams: the team types,
> the interaction modes, sizing, embedded-vs-centralized, and the **charter** that
> makes a platform team's scope and promises explicit.

**Estimated effort:** ~1.5 hours (theory + lab)
**You'll need:** [Modules 01.1–01.4](../).

## Learning objectives

By the end of this module you will be able to:

- Place the platform team within the four **Team Topologies** team types.
- Choose the right **interaction mode** (collaboration, X-as-a-Service,
  facilitating) for a situation.
- Reason about platform-team **sizing** and **embedded vs centralized** structures.
- Explain how a platform team avoids becoming a **bottleneck or gatekeeper**.
- Write a **Platform Team Charter** that sets mission, scope, support, and metrics.

---

## 1. Concept

### Team Topologies in one picture

*Team Topologies* (Skelton & Pais) proposes four — and only four — fundamental team
types. Limiting team types reduces organizational cognitive load, just as limiting
tool sprawl reduces engineering cognitive load.

```text
STREAM-ALIGNED        Aligned to a flow of work (a product, service, user journey).
                      The teams that deliver value to customers. Most teams are this.

PLATFORM              Provides internal products/services that REDUCE the cognitive
                      load of stream-aligned teams. (This is you.)

ENABLING              Helps other teams acquire missing capabilities; coaches, then
                      steps away. Temporary, skill-transfer focused.

COMPLICATED-SUBSYSTEM Owns a part that needs deep specialist expertise (e.g. a
                      video codec, an ML ranking engine). Few of these.
```

The **platform team** is its own type. Its purpose is explicit in the definition:
**reduce the cognitive load of stream-aligned teams** by providing compelling
internal services they consume with minimal effort.

### The platform team's posture: enable, don't control

Although "platform" and "enabling" are distinct team types, a *healthy* platform
team shares the enabling team's **spirit**: it exists to **accelerate** stream teams,
not to **control** them. The difference between enabling-spirited and
controlling platform teams is stark:

```text
Enabling-spirited platform team        Controlling / gatekeeper platform team
──────────────────────────────         ─────────────────────────────────────
"Here's a self-service capability;     "File a ticket and we'll provision it."
 use it whenever you want."            
Stream teams keep ownership & speed.    Stream teams wait in your queue.
You're measured by their success.       You're measured by your own throughput.
You become invisible infrastructure.    You become the bottleneck everyone blames.
```

The entire discipline tilts toward the left column. A platform team that controls
recreates siloed Ops (Module 01.1) with extra steps.

### The three interaction modes

Team Topologies defines exactly three ways teams interact. Knowing which mode you're
in — and which you *should* be in — prevents a lot of dysfunction.

```text
1. COLLABORATION      Two teams work closely together for a while to discover
                      something new. High bandwidth, high cost, temporary.
                      → Use when co-creating a brand-new capability with a pilot team.

2. X-AS-A-SERVICE     One team consumes something another provides, with minimal
                      ongoing interaction. Low bandwidth, scalable.
                      → The platform team's DEFAULT, steady-state mode.

3. FACILITATING       One team helps another improve or unblock, then steps away.
                      → Use to onboard a team to the platform, or clear an adoption
                        blocker (an enabling-style, temporary mode).
```

The platform team's **goal state is X-as-a-Service**: teams self-serve with little
hand-holding. But you *earn* that state by **collaborating** with early-adopter
teams to build the right thing, and by **facilitating** adoption until the paved
road is smooth. Watch the direction of travel: temporary collaboration →
facilitation → durable self-service. A platform stuck permanently in collaboration
or facilitation mode is a help desk, not a platform.

### Sizing

A common heuristic: **one platform engineer per ~8–12 developers** served. Treat it
as a rough starting point, not a law — the real driver is scope and maturity:

- A thin platform serving well-paved common cases needs fewer engineers per
  developer.
- A platform with many bespoke integrations, heavy support load, or immature
  automation needs more.
- If your ratio is drifting toward "one platform engineer per 3 developers," you're
  probably doing too much *for* teams (ticket-driven) instead of *enabling* them
  (self-service) — a signal to invest in automation, not headcount.

### Embedded vs centralized

Two common structures, often combined:

```text
CENTRALIZED                              EMBEDDED
───────────                              ────────
One platform team owns the platform      Platform engineers sit WITHIN stream teams
product; stream teams consume it.        (temporarily or rotating).

+ Consistency, clear ownership,          + Deep empathy, fast feedback, drives
  economies of scale.                      adoption from the inside.
− Risk of distance from real pain;       − Risk of fragmentation, inconsistent
  can feel like an ivory tower.            solutions, diluted platform focus.
```

A frequent healthy pattern: a **centralized platform team** that owns the product,
plus **embedded/rotating** platform engineers (or "platform champions") who keep it
close to real developer pain. Embedding is also a great way to run *facilitating*
mode during a team's onboarding.

### Avoiding the bottleneck / gatekeeper trap

The failure mode that kills platform teams: becoming the thing everyone must wait
for. Guardrails against it:

- **Default to self-service.** Every routine request a human fulfills is a product
  gap. Automate it away.
- **Prefer guardrails over gates.** Enforce safety with policy-as-code that runs
  automatically, not with a human approval queue (you'll build this with Kyverno
  later).
- **Provide escape hatches.** Let teams deviate safely rather than forcing
  everything through you — forced funnels create the bottleneck.
- **Measure yourself by *their* outcomes**, not your ticket count. If your success
  metric is "tickets closed," you've institutionalized the bottleneck.

### Communication: run the platform like a product team

Because it's a product with customers, a platform team communicates like one:

- **Office hours** — regular, open time for questions and help (facilitating mode,
  scheduled).
- **Changelog & release notes** — what changed, what's deprecated, what's coming.
- **Published roadmap & roadmap reviews** — visible priorities, with developer
  input.
- **A clear support channel** — where to get help, and what response to expect.
- **Internal marketing** — demos, success stories, docs. Adoption needs awareness.

These aren't niceties; they're how you build the trust that voluntary adoption
depends on.

---

## 2. Why it matters for platform engineering

You can build the perfect five-plane IDP and still fail if the team is a gatekeeper,
is sized to drown in tickets, or never communicates. Organizational design *is*
platform design. Getting the topology right means:

- stream teams actually get faster (the whole point);
- the platform team scales sub-linearly with the org (leverage), instead of needing
  a new hire for every few developers;
- the platform team stays close to real pain and keeps its product relevant;
- the platform team doesn't become the bottleneck it was created to remove.

The charter you'll write in the lab is the single most useful artifact for making
all of this explicit — and for protecting the team from scope creep and the
gatekeeper trap.

---

## 3. Mental model

```text
Platform team = a PLATFORM-type team whose JOB is to reduce stream teams' load,
                operating mostly as X-AS-A-SERVICE,
                using COLLABORATION to build and FACILITATION to onboard,
                measured by STREAM TEAMS' success — not its own ticket count.

Health check, ask continually:
  • Are we drifting into gatekeeper mode (tickets, approvals, "ask us")?
  • Are we stuck in collaboration/facilitation instead of reaching self-service?
  • Is our scope explicit — including what we DON'T own?
  • Do we communicate like a product team (office hours, changelog, roadmap)?
```

One sentence: **enable, don't gate; your scoreboard is other teams' speed.**

---

## 4. Minimal implementation

The smallest artifact that aligns a platform team is a **one-page charter**. Before
hiring, before building, a team that can answer these questions avoids most
topology failures:

```text
┌──────────────────────── Platform Team Charter ────────────────────────┐
│ Mission            One sentence: whom we serve and the load we remove. │
│ Capabilities owned What we provide as a service (the planes/paths).    │
│ Out of scope       What we deliberately do NOT own (prevents sprawl).  │
│ Support model/SLA  How to get help; what reliability we promise.       │
│ Interaction modes  Default X-as-a-Service; when we collaborate/facilitate. │
│ Communication      Office hours, changelog, roadmap, support channel.  │
│ Success metrics    Stream-team outcomes (adoption, time-to-prod, DORA).│
└────────────────────────────────────────────────────────────────────────┘
```

The two lines that do the most work are **Out of scope** (your defense against
becoming a catch-all) and **Success metrics defined as stream-team outcomes** (your
defense against becoming a ticket factory). You'll write a full charter in the lab.

---

## 5. Hands-on lab

Draft a **Platform Team Charter**: mission, owned capabilities, out-of-scope
capabilities, support model and SLA, communication channels, roadmap process, and
success metrics. This is the capstone of the Foundations phase — it ties together
your product brief, DX findings, and IDP assessment.

➡️ **[Start the lab: Platform Team Charter](./lab/README.md)**

---

## 6. Production considerations

- **Revisit the charter regularly.** Scope and maturity change; a stale charter
  stops protecting you. Review it quarterly with stakeholders.
- **Guard the "out of scope" line.** Pressure to absorb random responsibilities is
  constant. An explicit, agreed scope is your strongest defense against becoming an
  overloaded catch-all.
- **Automate to protect your ratio.** As you serve more teams, invest in self-service
  so headcount grows sub-linearly. If support load is rising faster than teams,
  you're too ticket-driven.
- **Make interaction modes explicit and time-boxed.** State when you're
  collaborating or facilitating and when that ends — so temporary high-touch work
  doesn't become a permanent help desk.
- **Fund communication.** Office hours, changelog, and roadmap work are part of the
  job, not overhead. Under-communicating platforms get under-adopted.
- **Tie performance to customer outcomes.** How the team is *evaluated* shapes its
  behavior; if leadership rewards ticket volume, you'll get a ticket factory.

---

## 7. Common mistakes

- **Becoming a gatekeeper.** Inserting the team into every change via tickets and
  approvals. *Fix:* self-service + policy guardrails; measure by stream-team
  outcomes.
- **Stuck in collaboration/facilitation forever.** Never reaching X-as-a-Service, so
  the team is a permanent help desk that can't scale. *Fix:* treat high-touch modes
  as temporary; invest in the paved road until teams self-serve.
- **No explicit scope.** Saying yes to everything, drowning, and losing product
  focus. *Fix:* an "out of scope" section and the discipline to hold it.
- **Wrong success metrics.** Measuring tickets closed or features shipped. *Fix:*
  adoption, time-to-first-deploy, DORA for served teams.
- **Mis-sizing via headcount instead of automation.** Hiring to keep up with ticket
  load. *Fix:* automate the repeated requests; headcount is a last resort.
- **Ivory-tower centralization.** A central team far from real pain, building what it
  imagines teams need. *Fix:* embed/rotate engineers; keep the discovery loop alive.
- **Silent platform.** Great tools nobody knows about or trusts. *Fix:* office hours,
  changelog, roadmap, internal marketing.

---

## 8. Assessment

**Knowledge checks**

1. Name the four Team Topologies team types. Which one is the platform team, and
   what is its explicit purpose?
2. What are the three interaction modes, and which is a platform team's *default*
   steady state?
3. Why should a platform team measure itself by stream teams' outcomes rather than
   its own ticket throughput?
4. Give two concrete practices that keep a platform team from becoming a bottleneck.

**Concept exercise**

> Explain how a platform team should relate to the rest of the engineering
> organization **without using the words "ticket," "approve," or "gatekeeper."**

**Trade-off exercise**

> Your platform team of 4 serves 60 developers (ratio ~1:15) and is drowning in
> support requests — people constantly ask you to provision things. Leadership
> offers to double your headcount. Should you take it? What would you do instead,
> and what does the drowning tell you?

<details>
<summary>Discussion</summary>

- **Q1:** Stream-aligned, platform, enabling, complicated-subsystem. The platform
  team's explicit purpose is to **reduce the cognitive load of stream-aligned teams**
  via compelling self-service internal products.
- **Q2:** Collaboration, X-as-a-Service, facilitating. Default steady state is
  **X-as-a-Service**.
- **Q3:** Because the platform exists to accelerate *other* teams; ticket throughput
  measures how much of a bottleneck you are, not how much value you create.
  Optimizing ticket count institutionalizes the bottleneck.
- **Q4:** e.g. default to self-service (automate routine requests); enforce safety
  with policy-as-code instead of human approval gates; provide escape hatches;
  measure success by stream-team outcomes.
- **Trade-off:** Be cautious about just adding headcount — if the work is
  ticket-driven, more people scales the *bottleneck*. The drowning is a signal that
  routine requests aren't self-service. Invest the next hire (or two) in *automation*
  that turns the top repeated requests into self-service, which scales to all 60+
  developers, rather than growing a help desk linearly.

</details>

---

## 9. Further reading

- Matthew Skelton & Manuel Pais — [*Team Topologies*](https://teamtopologies.com/)
  (team types and interaction modes)
- [Team Topologies — key concepts (free summary)](https://teamtopologies.com/key-concepts)
- CNCF — [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)
  (organization dimension)
- Humanitec / PlatformEngineering.org — platform team operating-model resources

---

## Phase 1 complete 🎉

You now have the lenses the rest of the course relies on: platform-as-a-product,
developer experience, the five-plane IDP, and platform team topology. And you've
produced a portfolio set of artifacts — discovery findings, a product brief, a DX
audit, an IDP assessment, and a team charter.

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [01.4 — The Internal Developer Platform](../04-the-internal-developer-platform/)
· _Next phase:_ [02 · Containerization →](../../02-containerization/)
