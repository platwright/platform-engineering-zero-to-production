# Module 20.3 — Platform Engineering Metrics

> You cannot manage what you cannot measure — and you cannot prove a platform's value
> without the right numbers. This module turns the "measure outcomes, not output"
> principle from [Module 01.2](../../01-platform-foundations/02-platform-as-a-product/)
> and the DORA/SPACE frameworks from [Module 01.3](../../01-platform-foundations/03-developer-experience/)
> into a concrete **platform metrics set** and a **health dashboard** — the
> instrument panel a mature platform team runs on, and the evidence a sponsor funds.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 01.2 Platform as a Product](../../01-platform-foundations/02-platform-as-a-product/) and [01.3 Developer Experience](../../01-platform-foundations/03-developer-experience/) (DORA, SPACE). Optional: a running [Grafana from Project 3](../../12-platform-project-03/) to import the sample dashboard. No cloud required — a paper sketch works.

## Learning objectives

By the end of this module you will be able to:

- Apply **DORA** metrics in the platform context — both to the platform team's *own*
  delivery and to the teams the platform serves.
- Use the **SPACE** framework to measure developer experience without single-metric
  tunnel vision, and know which SPACE metrics are dangerous to weaponize.
- Define **adoption metrics** that make "platform as a product" measurable.
- Design a **platform health dashboard** with the four essential panels, and tell a
  decision-driving dashboard from a vanity one.
- Write a metric definition that is unambiguous: what, source, cadence, target, and a
  paired guardrail.

---

## 1. Concept

### Three lenses, not one number

A platform is a product, so you measure it like one — from three complementary
angles. No single number captures platform health; together these do:

```text
  DELIVERY (DORA)        EXPERIENCE (SPACE)        ADOPTION (product)
  ───────────────        ──────────────────        ──────────────────
  Is delivery fast       Do developers have a       Are teams actually
  and safe?              good, sustainable          choosing the paved
                         experience?                road?
  (speed + stability)    (balanced, human)          (the north star)
```

Miss any lens and you get a distorted picture: fast delivery with miserable
developers, happy developers nobody can see are unproductive, or great tooling at 10%
adoption. You need all three.

### DORA in the platform context

The four **DORA** metrics (from [Module 01.3](../../01-platform-foundations/03-developer-experience/))
measure delivery performance — *speed* (deployment frequency, lead time for changes)
balanced against *stability* (change failure rate, time to restore). In a platform,
they apply in **two directions**, and conflating them is a common error:

```text
Direction 1 — the platform's OWN delivery (the platform is software too):
  Deployment frequency  how often does the platform itself ship?
  Lead time for changes  a platform-config PR → running in production
  Change failure rate    % of platform changes that cause an incident
  Time to restore        MTTR for platform incidents

Direction 2 — the platform's EFFECT on the teams it serves:
  The platform should move ITS CUSTOMERS' DORA metrics in the right direction.
  A good platform makes the teams using it deploy more often, with lower
  lead time and failure rate, than teams not using it.
```

Direction 1 keeps the platform team honest (practice what you preach). Direction 2 is
the *value argument*: "teams on the golden path deploy 3× more often with half the
change-failure rate" is the sentence that justifies the platform's existence.

### SPACE for developer experience

**DORA tells you how fast and safe delivery is; it does not tell you how developers
feel or whether they're burning out.** The **SPACE** framework fixes single-metric
tunnel vision by insisting on multiple dimensions:

```text
S — Satisfaction & well-being   developer NPS / periodic DX survey
P — Performance                 outcomes, e.g. deployment frequency per team
A — Activity                    counts: commits, deployments, PRs per team  (⚠ handle with care)
C — Communication & collaboration  e.g. PR review time
E — Efficiency & flow           time-to-first-deployment for a new team
```

SPACE's central lesson, worth tattooing on the dashboard: **never measure
productivity with one number, and never use Activity counts as individual
productivity.** Commits-per-developer and PRs-per-person are trivially gamed and
corrosive to trust the moment they're used to rank people (Goodhart's law). Use
Activity at the *team/platform* level, always paired with a Satisfaction and a
Performance metric so you can't "win" one by wrecking another.

### Adoption — the north-star lens

From [Module 01.2](../../01-platform-foundations/02-platform-as-a-product/): adoption
is the scoreboard. A platform only reduces cognitive load for the teams that actually
use it. Make it measurable:

```text
% of teams using the golden path            ← the headline adoption number
% of services in the software catalog       ← visibility / discoverability
% of services with SLOs defined             ← reliability maturity (Phase 17)
% of services using platform-managed o11y   ← observability-as-a-service (Phase 11)
```

These also *double as maturity indicators* (Module 20.1): "adoption > 80% on golden
paths" is literally the Level 4 signal.

### The platform health dashboard

All three lenses converge on one **single pane of glass** — the four panels a
platform lead should be able to glance at any morning:

```text
┌──────────────────────────────┬──────────────────────────────┐
│ ① Platform service SLO status │ ② Active incidents            │
│   are our own services        │   what's on fire right now?   │
│   meeting their SLOs? (17)    │   (open, severity, age)       │
├──────────────────────────────┼──────────────────────────────┤
│ ③ Change activity             │ ④ Developer experience trend  │
│   recent platform deploys,    │   DX survey / NPS over time,  │
│   lead time, change-fail rate │   adoption %, time-to-first-  │
│   (DORA, direction 1)         │   deploy (SPACE + adoption)   │
└──────────────────────────────┴──────────────────────────────┘
```

Real-time on the left (is it healthy *now*?), trend on the right (is it getting
*better*?). That's the whole instrument.

---

## 2. Why it matters for platform engineering

- **Metrics are how a platform defends its budget.** Platform teams are cost centers
  until they can show outcomes. "Teams on our golden path restore from incidents 4×
  faster" turns a line item into an investment. Without metrics, the platform is the
  first thing cut in a downturn.
- **They direct the roadmap.** The adoption and DX numbers tell you *which* pain to
  remove next (the prioritization from Module 01.2), and the maturity profile
  (Module 20.1) is literally built from them. Metrics close the product loop:
  discover → build → **measure** → discover again.
- **They prevent self-deception.** A platform team is emotionally invested in its
  work. Honest metrics — especially satisfaction and *depth* of adoption — are the
  antidote to "everyone loves it" when the truth is "everyone complies." This is the
  captive-audience trap from Module 01.2, caught by data.
- **The wrong metrics actively harm.** Measuring the platform team's *output*
  (features shipped, tickets closed, pipelines run) rewards activity over value and
  can institutionalize the bottleneck. Choosing metrics is choosing behavior.

## 3. Mental model

Use **Goal → Question → Metric** (GQM) so every number has a reason to exist, and
remember the balance rule so no metric stands alone:

```text
GOAL      "Developers ship safely with low friction."
   │
   ▼
QUESTION  "How quickly can a new team reach production, and do they trust it?"
   │
   ▼
METRIC    time-to-first-deploy (speed)  +  change-failure rate (quality)
          +  DX survey (satisfaction)   ← a balanced trio, never one alone

The balance rule (from SPACE):
   pair every SPEED metric with a QUALITY metric and a SATISFACTION metric,
   so you cannot improve one by silently wrecking another.
```

Two durable rules to keep a year from now:

- **Measure outcomes, not output.** Count what happens *for your customers*
  (adoption, their DORA, their satisfaction), not what your team *produced*.
- **A metric with no decision attached is vanity.** Before adding a number to the
  dashboard, name the decision it will change. If none, cut it.

## 4. Minimal implementation

The smallest useful metrics program is a short, sharp **metric definition table** —
far more valuable than a wall of auto-collected charts nobody reads. Define each
metric unambiguously:

```text
Metric            | What it is                 | Source        | Cadence | Target  | Paired guardrail
──────────────────┼────────────────────────────┼───────────────┼─────────┼─────────┼──────────────────
Golden-path       | % of services created from | catalog /     | weekly  | > 80%   | DX survey (don't
 adoption         | the golden path            | Git           |         |         | mandate to hit it)
Time-to-first-    | new team: repo → first      | pipeline      | monthly | < 1 day | change-fail rate
 deploy           | prod deploy                 | timestamps    |         |         | (speed vs safety)
Platform change-  | % of platform changes that | incident +    | monthly | < 15%   | deployment freq
 failure rate     | cause an incident          | deploy logs   |         |         | (safety vs speed)
Developer NPS     | "recommend the platform?"  | quarterly     | quarterly| > +20  | adoption depth
                  |  −100..+100                | survey        |         |         |
```

Five rules make these honest:

- **Every metric names a source and a cadence.** "We'll measure adoption" without
  *how* and *how often* is a wish, not a metric.
- **Every metric has a paired guardrail.** The guardrail is the metric you must *not*
  wreck while improving this one (speed paired with safety, adoption paired with
  satisfaction). This is SPACE operationalized.
- **Baseline before you build.** Record today's number first, or you can never prove
  impact — the "baseline before you build" rule from Module 01.2.
- **Keep the set small.** Five to eight metrics you act on beat fifty you ignore.
- **No individual-productivity metrics.** Team and platform level only.

A starter **Grafana dashboard JSON** (the four panels above) ships with the lab — a
concrete, importable sketch you can adapt, or you can draw the same four panels on
paper.

## 5. Hands-on lab

You'll define a small, balanced platform metrics set (DORA + SPACE + adoption) with
sources, cadences, targets, and paired guardrails, then sketch the four-panel health
dashboard — importing the provided Grafana JSON or drawing it by hand.

➡️ **[Start the lab: Define a Platform Metrics Set + Health Dashboard](./lab/README.md)**

## 6. Production considerations

- **Instrument from day one; baseline before you build.** You cannot show "before and
  after" if you never captured "before." Decide how you'll measure adoption and
  time-to-deploy *before* v1 ships (Module 01.2).
- **Protect people from their own metrics.** Never expose individual Activity counts
  (commits, PRs per person) as productivity — it destroys trust and invites gaming.
  Aggregate to team/platform level, and say so publicly.
- **Watch data quality.** A dashboard built on flaky or inconsistent sources is worse
  than none — it drives confident wrong decisions. Validate the pipeline; annotate
  known gaps.
- **Leading vs lagging.** Satisfaction and adoption *lead* (they predict future
  outcomes); incident counts *lag*. Put both on the dashboard so you can act early,
  not just autopsy.
- **Survey fatigue is real.** DX surveys decay if too frequent or never acted on.
  Run them on a sane cadence (quarterly), keep them short, and *close the loop* —
  show developers what changed because of their answers, or they'll stop answering.
- **The dashboard must drive a ritual.** A dashboard nobody looks at is theater.
  Anchor it to a recurring platform review (Module 20.4) where the numbers actually
  change a decision. If no decision ever changes, cut the metric.
- **Beware Goodhart.** "When a measure becomes a target, it ceases to be a good
  measure." Targets guide; they must not become OKRs people game. Pair every target
  with its guardrail and review the pair.

## 7. Common mistakes

- **Single-metric tunnel vision.** Reporting one "productivity" number. — It's gamed
  and hides trade-offs (speed up, quality down). — *Fix:* SPACE — pair speed with
  quality and satisfaction; report a balanced set.
- **Vanity metrics.** Pipelines run, features shipped, tickets closed. — They measure
  the platform team's *activity*, not customer *outcomes*. — *Fix:* adoption,
  customers' DORA, time-to-deploy, NPS.
- **Weaponizing Activity counts.** Ranking engineers by commits/PRs. — Corrosive and
  trivially gamed (Goodhart). — *Fix:* team/platform aggregation only; never
  individual.
- **No baseline.** Building the platform, then being unable to prove it helped. —
  "Before" is gone. — *Fix:* measure today's numbers before you ship v1.
- **Measuring output, not outcomes.** Counting what the platform team produced. — It
  rewards busywork and can entrench the bottleneck. — *Fix:* measure what changes for
  the teams you serve.
- **A dashboard nobody uses.** A beautiful wall of charts with no attached decision.
  — Data theater. — *Fix:* GQM — every metric earns a decision; anchor the dashboard
  to a review ritual.
- **Mandating adoption to hit the number.** Forcing teams onto the golden path to make
  the headline metric green. — Compliance masks a product that isn't actually better,
  and NPS craters unseen. — *Fix:* pair adoption with satisfaction; win adoption by
  being the best option.

## 8. Assessment

**Knowledge checks**

1. Name the four DORA metrics and explain the *two directions* they apply in for a
   platform.
2. What are the five SPACE dimensions, and which one is dangerous to use as an
   individual-productivity metric? Why?
3. Give three adoption metrics and explain why adoption is the north-star lens.
4. What are the four panels of a platform health dashboard, and which side is
   real-time vs trend?

**Concept exercise**

> Describe what a platform team should measure **without naming DORA, SPACE, or any
> specific metric.** Talk in terms of the *questions* you want the numbers to answer
> (speed, safety, experience, adoption) and the balance rule.

**Trade-off / design exercise**

> Your dashboard shows golden-path adoption at 92% (great!) but developer NPS at −15
> and rising support tickets. A VP wants to celebrate the 92%. What's your read, what
> single additional cut of the data would you pull, and what does the combination most
> likely mean?

<details>
<summary>Discussion</summary>

- **Q1:** Deployment frequency, lead time for changes, change failure rate, time to
  restore. Direction 1: the platform team's *own* delivery (platform-config PR →
  prod, platform incident MTTR). Direction 2: the platform's *effect* — it should
  improve the DORA metrics of the teams that adopt it (the value argument).
- **Q2:** Satisfaction, Performance, Activity, Communication, Efficiency. **Activity**
  (commits/PRs/deploys counted) is dangerous as individual productivity — it's
  trivially gamed and corrodes trust (Goodhart). Use it at team level, paired with
  Satisfaction and Performance.
- **Q3:** e.g. % of teams on the golden path, % of services in the catalog, % with
  SLOs, % on platform-managed observability. Adoption is the north star because a
  platform only reduces load for teams that actually use it; low adoption means the
  value didn't land, regardless of features.
- **Q4:** ① platform SLO status, ② active incidents (both real-time, left), ③ change
  activity/DORA, ④ DX trend/adoption (both trend, right).
- **Trade-off:** High adoption + negative, *rising* NPS + more tickets strongly
  suggests **mandated or forced adoption masking a bad experience** (the captive-
  audience trap). Pull adoption *depth* / satisfaction split by whether teams are on
  the path by choice vs mandate, and the top ticket themes. The 92% is likely
  compliance, not love — don't celebrate it; investigate the friction before teams
  route around you the moment they can.

</details>

## 9. Further reading

- Forsgren, Storey, Maddila, Zimmermann, Houck, Butler — [*The SPACE of Developer
  Productivity*](https://queue.acm.org/detail.cfm?id=3454124) (ACM Queue)
- DORA — [metrics, the quick check, and research](https://dora.dev/)
- Forsgren, Humble, Kim — [*Accelerate*](https://itrevolution.com/product/accelerate/)
  (the research behind DORA)
- Victor Basili et al. — [Goal–Question–Metric (GQM) overview](https://en.wikipedia.org/wiki/GQM)
  (deriving metrics from goals)
- CNCF TAG App Delivery — [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)
  (the Measurement dimension)
- Grafana — [dashboard best practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [20.2 — AI-Assisted Platform Engineering](../02-ai-assisted-platform-engineering/)
· _Next:_ [20.4 — Platform Engineering Culture and Organization →](../04-platform-engineering-culture/)
