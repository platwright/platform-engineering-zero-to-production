# Module 17.1 — Platform SRE Fundamentals

> A platform team is Site Reliability Engineering for *other engineers*. When your
> platform wobbles, every stream-aligned team wobbles with it — so your reliability
> bar is **higher** than any single app team's. This module defines platform SRE,
> explains the blast-radius problem, and introduces the discipline's central enemy:
> **toil**, the manual repetitive work you must measure and automate away.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Phase 11 · Observability](../../11-observability-engineering/) and a pen — this module's lab is a measurement worksheet, no cluster required.

## Learning objectives

By the end of this module you will be able to:

- Explain why a platform team operates at a **higher reliability bar** than the
  teams it serves, using the blast-radius argument.
- Name the **four responsibilities** of platform SRE and how they reinforce
  each other.
- Define **toil** precisely and distinguish it from ordinary engineering work.
- **Measure** toil as a fraction of team time and set a budget for it.
- Identify the biggest toil sources in a platform and the automation that removes
  them.

---

## 1. Concept

### SRE, applied to the platform itself

Site Reliability Engineering (SRE) is Google's name for *treating operations as a
software problem*: you run production to explicit reliability targets, you cap the
amount of manual work you tolerate, and you automate everything else. Classic SRE
teams run *application* services. **Platform SRE** points the same discipline at the
platform — the clusters, GitOps controllers, registries, secret operators, and
portals that *other teams* build on.

The methods are identical to app SRE — SLOs, error budgets, incident response,
capacity planning. What changes is **who your users are** and **what an outage
costs**. Your users are engineers, and your outage is an *outage multiplier*.

### The higher reliability bar: blast radius

Here is the defining fact of platform SRE:

```text
An app team's outage:          A platform team's outage:
  one product is down             EVERY team's delivery is down

  payments-api 500s               Argo CD stops syncing  → nobody can deploy
  → payments customers hurt       registry unreachable   → no image pulls, no new pods
                                  secrets stop syncing   → apps fail on next restart
                                  cluster API down       → nothing can be changed at all
```

When a platform service fails, the failure **fans out** to all consumers at once.
Fifty teams are blocked by one incident. That is why a platform's SLO targets are
typically *stricter* than the services running on it — a 99.9% platform supporting
teams that each want 99.9% is already the ceiling on what those teams can achieve,
because your downtime is included in *their* downtime. You are in everyone's
critical path, so you must be more reliable than any one of them.

> The rule to internalize: **a platform is only as trustworthy as its worst
> critical-path dependency.** If teams cannot rely on your paved road being up, they
> build their own — and your platform has failed as a product.

### The four responsibilities of platform SRE

Platform SRE work organizes into four reinforcing areas, which are the rest of
this phase:

- **SLOs and error budgets** (Module 17.2) — define "working" as a number for every
  platform service, and let the budget govern how fast you change things.
- **Toil reduction** (this module) — measure the manual operational load and
  automate it away so the team scales with adoption.
- **Capacity planning** (Module 17.4) — make sure there are enough nodes of the
  right shape, without paying for idle ones.
- **Incident management** (Module 17.3) — detect, respond to, mitigate, and learn
  from failures with a repeatable process.

They reinforce each other: good SLOs tell you *when* an incident is happening;
incident postmortems generate *toil-reduction* and *capacity* work; eliminating
toil frees the time you need to do the other three well.

### Toil: the central enemy

**Toil** is Google's term for a specific kind of work. It is operational work tied
to running a service that is:

- **manual** — a human runs it;
- **repetitive** — you have done it before and will again;
- **automatable** — a machine could do it;
- **tactical / reactive** — interrupt-driven, not strategic;
- **devoid of enduring value** — the service is no better after than before;
- **O(n) with growth** — it scales linearly with users, traffic, or teams.

Toil is *not* "work I dislike." Answering a hard design question, writing a new
controller, or debugging a novel failure is engineering, even when it is tedious.
The test is the list above — especially **"scales linearly with growth"** and
**"leaves nothing better behind."** Manually creating a namespace for every new team
is toil: the hundredth one teaches you nothing and takes as long as the first.

Why obsess over it? Because toil **grows with adoption**. A successful platform adds
teams; if onboarding each team is manual, your ops load grows with your success
until the team is 100% firefighting and 0% building — the death spiral of a
platform team. SRE's answer is blunt: **cap toil** (Google's guidance is to keep it
below ~50% of a team's time) and spend the rest *engineering toil away*.

### Measuring toil

You cannot manage what you do not measure. Toil is measured as a **fraction of team
time**:

```text
toil % = (hours spent on toil) / (total working hours)   over a window (e.g. a sprint)
```

The practical method: for a sprint or two, every engineer tags their time as
**toil** or **engineering/project** work (a simple tally in a shared sheet is
enough). You will usually find a few categories dominate. Then you rank those
categories by `hours × frequency` and attack the top of the list with automation —
the same "start from observed pain" move you used for the platform as a whole in
Module 01.1, now pointed at your *own* operations.

### Where platform toil comes from

The usual top offenders on a Kubernetes platform:

```text
toil source                     manual form                automation that kills it
──────────────────────────────  ─────────────────────────  ─────────────────────────
onboarding a new team           hand-create namespace,      GitOps + templates /
                                RBAC, quotas, limits        a "new team" generator
secret creation / rotation      kubectl create secret,      External Secrets Operator
                                rotate by hand              (Module 13.4)
cluster / addon upgrades        click through consoles,     IaC + staged rollout,
                                manual node drains          automated canary upgrades
responding to the same alert    manual restart every time   a runbook, then an operator
certificate renewal             renew + redeploy by hand    cert-manager
access requests                 edit RBAC per request       self-service + policy as code
```

Notice the pattern: nearly every entry is removed by something you already built
earlier in this course. Platform SRE is where that earlier work pays reliability
dividends — **automation is the primary tool against toil**, and you have been
accumulating automation the whole time.

---

## 2. Why it matters for platform engineering

- **It is the economic case for the platform.** The platform's whole promise is
  leverage: a small team multiplying many teams. Toil destroys leverage — if ops
  load grows linearly with adoption, the platform stops scaling exactly when it
  succeeds. Measuring and capping toil protects the leverage.
- **It sets the reliability expectation correctly.** Framing the blast radius makes
  teams (and leadership) understand why platform reliability investment is not
  gold-plating — it is the floor under everyone else's reliability.
- **It makes the team sustainable.** A team at 80% toil is burning out and cannot do
  the project work (SLOs, capacity, chaos, DR) that *prevents the next fire*. The
  toil budget is how you protect time to engineer.
- **It prioritizes ruthlessly.** "Which automation should we build next?" stops
  being a matter of taste and becomes "which toil category costs the most hours?" —
  a data-driven backlog.

---

## 3. Mental model

Think of a platform team as a tank with a **leak** (toil) and an **inflow** of
engineering time. Reliability and new capabilities are built from whatever time is
left after the leak:

```text
                total team time
                      │
          ┌───────────┴────────────┐
          ▼                        ▼
      TOIL (the leak)        ENGINEERING (the build)
   manual, repetitive,       SLOs, automation, capacity,
   O(n) with growth          chaos, DR, new capabilities
          │                        │
          ▼                        ▼
   grows with adoption      is what PREVENTS future toil
   unless you plug it

   If toil > ~50%, the leak outruns the build:
   the team spends all day bailing and never fixes the hull.

   SRE move:  MEASURE the leak → cap it → spend saved time
              welding it shut (automation) → leak shrinks → repeat.
```

The insight: toil is not just annoying, it is **self-reinforcing**. Time lost to
toil is time you cannot spend eliminating toil, so it compounds. The only way out is
to deliberately protect engineering time and point it at the biggest leaks first.

---

## 4. Minimal implementation

You do not need a tool to start — you need a tally. The smallest useful toil
measurement is a table each engineer fills in for one sprint:

```text
task                     type         minutes  times/sprint   toil-minutes
───────────────────────  ───────────  ───────  ────────────   ────────────
create namespace+RBAC    toil             20         8              160
rotate a leaked secret   toil             15         3               45
debug novel CNI bug      engineering      —          —                —
write upgrade runbook    engineering      —          —                —
restart stuck ESO pod    toil             10         6               60
───────────────────────  ───────────  ───────  ────────────   ────────────
                                          toil total this sprint:   265 min
```

Then compute the fraction and rank the categories:

```bash
# toil fraction for one engineer, 2-week sprint at ~60 productive hours
echo "scale=3; 265 / (60*60) " | bc      # minutes of toil / minutes available
# → 0.073  → ~7% of this person's time, this sprint
#
# Ranked by cost, the backlog writes itself:
#   1. namespace+RBAC onboarding (160 min)  → template it (GitOps generator)
#   2. restart stuck ESO pod       (60 min)  → add a liveness probe + runbook/operator
#   3. secret rotation             (45 min)  → External Secrets Operator
```

That is the entire method: **tag, total, rank, automate the top item, repeat next
sprint.** No dashboard required to begin — though at scale you graph the toil
fraction over time and treat a rising line as a reliability risk. The lab turns this
into a reusable worksheet you can run on a real team.

---

## 5. Hands-on lab

You will run a toil audit: inventory a platform team's operational tasks, classify
each as toil or engineering against the six-point test, quantify it as a fraction of
team time, and produce a **ranked automation backlog**. The deliverable is the exact
artifact an SRE lead brings to planning to justify automation work.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Budget toil explicitly, like an SLO.** Pick a cap (Google uses ~50%) and track
  the fraction per sprint. When it trends up, that is a signal to stop taking on new
  scope and invest in automation — the same discipline as an error-budget policy.
- **Protect the engineering time.** Toil is interrupt-driven and will expand to fill
  all available hours. Shield project time with an on-call/interrupt rotation so one
  person absorbs the toil while the rest build the automation that removes it.
- **Not all toil is worth automating.** If automating a task costs more than the toil
  it saves over its lifetime, do not. Estimate `toil-saved-over-a-year` versus
  `build-plus-maintain cost` before committing.
- **Beware automation that becomes toil.** A brittle script that needs babysitting is
  just toil wearing a costume. Automation needs the same reliability standard as the
  platform; otherwise you have moved the leak, not plugged it.
- **Make toil visible to leadership.** A graph of "team time spent on toil" is the
  single most effective argument for headcount or for pausing feature work to pay
  down operational debt.

## 7. Common mistakes

- **Treating toil as "just part of the job."** — Teams normalize manual work and
  never measure it, so it grows invisibly until they are 90% firefighting. *Fix:*
  measure the fraction every sprint and treat a rising line as an incident in slow
  motion.
- **Confusing toil with all boring work.** — Labeling hard-but-novel engineering as
  "toil" and trying to automate the unautomatable. *Fix:* apply the six-point test;
  if it is not repetitive *and* automatable *and* value-less, it is engineering.
- **Automating the wrong thing first.** — Building the fun automation instead of the
  expensive one. *Fix:* rank by `hours × frequency` and attack the top of the list.
- **Automation without an owner or SLO.** — A clever script nobody maintains rots
  into a new source of toil and outages. *Fix:* treat internal automation as a
  product with an owner, tests, and monitoring.
- **Ignoring the blast-radius argument when prioritizing.** — Spending reliability
  effort evenly instead of on critical-path services. *Fix:* weight by how many
  teams a failure blocks; the registry and Argo CD matter more than a nice-to-have
  dashboard.

## 8. Assessment

**Knowledge checks**

1. Why does a platform team carry a higher reliability bar than an app team? Use the
   word "blast radius" in your answer.
2. List the six properties that make a task toil. Which one captures *why* toil is
   dangerous as a platform grows?
3. How do you measure toil, and what is a common cap for it?
4. Give two platform toil sources and the automation that removes each.
5. Why is "automate the task I find most annoying" a bad prioritization rule?

**Concept exercise**

> Explain to a new platform engineer why onboarding teams by hand is dangerous —
> **without using the word "toil."** Make them feel why it gets worse as the platform
> succeeds.

**Trade-off / debugging exercise**

> Your team is at ~70% toil and leadership wants three new platform features this
> quarter. You have a ranked toil list where the top item (manual namespace + RBAC
> onboarding) costs ~8 hours/week and is growing. Argue for what the team should do
> first, and how you would make the case with numbers rather than opinion.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A platform sits in every team's critical path, so one platform outage fans
  out to *all* consumers at once — the blast radius is the whole org. Since your
  downtime is included in every team's downtime, you must be more reliable than any
  one of them.
- **Q2:** Manual, repetitive, automatable, tactical/reactive, no enduring value, and
  **O(n) with growth** — the last one is why toil is dangerous: it scales with
  adoption, so success makes it worse unless you automate it.
- **Q3:** As a fraction of team time (toil hours ÷ total hours) measured over a
  sprint; a common cap is ~50%.
- **Q4:** e.g. namespace/RBAC onboarding → GitOps templates/a generator; secret
  rotation → External Secrets Operator; upgrades → IaC + staged automation.
- **Q5:** It optimizes for feelings, not cost. The expensive toil (high hours ×
  frequency, growing with adoption) may be boring; ranking by cost attacks the leak
  that actually threatens the team's capacity.
- **Trade-off:** At 70% toil the team has almost no capacity to ship features
  reliably, and the top item is *growing*, so the situation worsens even if you add
  nothing. Make the case with the measured fraction and a projection: automate
  onboarding first (it frees ~8 hrs/week and stops the linear growth), which *creates*
  the capacity to deliver the features afterward. Automating first is how you ship
  more, not less.

</details>

## 9. Further reading

- Google — [SRE Book: Eliminating Toil](https://sre.google/sre-book/eliminating-toil/)
- Google — [SRE Book: Introduction](https://sre.google/sre-book/introduction/) and
  [SRE Workbook](https://sre.google/workbook/table-of-contents/)
- Google — [SRE Book: Embracing Risk](https://sre.google/sre-book/embracing-risk/)
  (why 100% is the wrong target)
- Matthew Skelton & Manuel Pais — [*Team Topologies*](https://teamtopologies.com/)
  (platform teams as enablers, cognitive load)
- CNCF — [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 13 overview](../README.md)
· _Next:_ [17.2 — Platform SLOs →](../02-platform-slos/)
