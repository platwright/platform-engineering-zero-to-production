# Module 01.2 — Platform as a Product

> The most important mindset shift in platform engineering: your platform is a
> **product**, your developers are its **customers**, and your job is to earn their
> adoption — not to mandate it. This module gives you the product toolkit: jobs to
> be done, personas, journey mapping, roadmapping from pain, and the metrics that
> tell you whether it's working.

**Estimated effort:** ~1.5 hours (theory + lab)
**You'll need:** [Module 01.1](../01-what-is-platform-engineering/) and, ideally, your
findings from its lab.

## Learning objectives

By the end of this module you will be able to:

- Explain what "platform as a product" means and why it's the difference between
  adoption and shelfware.
- Use the **Jobs to be Done** framing to define what developers "hire" the platform
  for.
- Map a **developer journey** from idea to production and spot the friction.
- Build a platform roadmap driven by developer pain, and make a defensible
  **build-vs-buy** call.
- Choose the right **success metrics** (DORA, adoption, NPS, time-to-first-deploy).

---

## 1. Concept

### Product thinking for an internal platform

A product is something people **choose** to use because it solves a problem for
them better than the alternatives. That one sentence reframes everything a platform
team does:

| Project thinking | Product thinking |
|------------------|------------------|
| "Ship the platform, then we're done." | "The platform is never done; it has a roadmap." |
| "We built it; teams must use it." | "We earn adoption by being the best option." |
| Measures **output** (features shipped). | Measures **outcomes** (adoption, developer speed). |
| Requirements come from the platform team. | Requirements come from customer pain. |
| Success = it exists. | Success = people use it and are better off. |

Internal platforms have one advantage and one trap compared to external products:

- **Advantage:** you have *direct access* to every customer. They sit next to you.
  There is no excuse for not knowing their pain.
- **Trap:** you may have a *captive* audience (leadership can mandate your tool).
  Mandates hide failure — people comply and quietly route around you. **Treat
  developers as if adoption were voluntary**, because in every way that matters, it
  is.

### Service provider, not gatekeeper

A platform team is a **service provider**. Its posture is *"here is a capability you
can use whenever you want, by yourself."* The failure mode is becoming a
**gatekeeper**: *"file a ticket and wait for us to do it for you."* Gatekeeping
recreates the very bottleneck platform engineering exists to remove (more in
Module 01.5).

### Know your customer: stream-aligned teams

Your primary customers are **stream-aligned teams** — teams aligned to a flow of
work (a product, a service, a user journey). They want to deliver their stream's
value with minimal distraction. Everything the platform offers should be judged by:
*does this help a stream-aligned team go faster and safer with less load?*

### Jobs to be Done (JTBD)

People don't want a product; they want to make **progress** in a situation. They
"hire" a product to get a **job** done. The classic framing:

```text
When <situation>, I want to <motivation>, so I can <expected outcome>.
```

For a platform, JTBD keeps you honest about outcomes instead of features:

- ❌ Feature thinking: *"Developers need a Backstage catalog."*
- ✅ JTBD thinking: *"**When** I'm paged for an unfamiliar service, **I want to**
  quickly find who owns it and where it runs, **so I can** resolve the incident
  without hunting through Slack."*

Notice the job doesn't mention a tool. A catalog is one way to serve it; so is a
well-maintained spreadsheet. The job tells you *what good looks like*; the solution
is an implementation detail you choose later (and can change).

### Developer journey mapping

A **developer journey map** lays out every step a developer takes to go from idea
to running-in-production, annotating each step with time, effort, emotion, and
hand-offs. It makes friction visible.

```text
Idea → Scaffold → Code → Test → Build → Deploy to dev → Get cloud resources →
Wire secrets → Deploy to prod → Observe → Operate / on-call

For each step, capture:
  ⏱  time it takes        🤝 who you wait on
  😊/😤 how it feels       🔁 how often it's redone
```

The steps with the most pain, the longest waits, and the most hand-offs are your
roadmap's raw material.

### Roadmapping from pain

A platform roadmap is **a prioritized list of developer pains you will remove**,
not a list of technologies you want to adopt. Prioritize with evidence:

```text
priority ≈ (how much it hurts) × (how often) × (how many teams affected)
           ─────────────────────────────────────────────────────────────
                        (cost / effort to solve)
```

This is why Module 01.1 started with interviews: the roadmap flows from discovery.

### Build vs buy

For each capability, decide whether to **build**, **buy/adopt** (SaaS or
open-source), or **wait**. A rough guide:

- **Buy/adopt** when the capability is a **commodity** — not a differentiator, and
  well-served by existing tools (CI runners, metrics storage, secret managers).
  Don't build what you can assemble.
- **Build (thinly)** the **glue and the golden path** — the opinionated integration
  that fits *your* organization. This is where your platform's real value lives.
- **Wait** when there's no evidence of real demand yet (TVP discipline).

> Heuristic: *buy the commodities, build the opinions.* Your differentiation is
> rarely a storage engine; it's the paved road that ties commodities together for
> your developers.

### Measuring success

Pick metrics that reflect **outcomes and adoption**, not vanity output:

- **Adoption** — the north star. *% of teams/services on the golden path.* If this
  isn't rising, nothing else matters.
- **Time-to-first-production-deployment** — how long for a brand-new team/service to
  reach prod. A direct measure of the paved road's quality.
- **DORA metrics** (delivery performance): deployment frequency, lead time for
  changes, change failure rate, time to restore. The platform should move these in
  the right direction *for the teams using it*.
- **Developer satisfaction** — NPS ("how likely are you to recommend the platform?")
  and periodic surveys. Qualitative, but it predicts adoption.

> Beware vanity metrics ("number of features," "pipelines run"). They measure your
> activity, not your customers' success.

---

## 2. Why it matters for platform engineering

Product thinking is the difference between a platform that gets *used* and one that
becomes an expensive internal ghost town. The graveyard of platform engineering is
full of technically excellent systems nobody adopted, because:

- they solved a problem the team found interesting, not one developers felt;
- adoption was mandated, so real sentiment stayed hidden until it was too late;
- there was no feedback loop, so the platform drifted further from reality each
  quarter.

Every technical decision later in this course — which CI template, which GitOps
pattern, which golden path — is ultimately a *product* decision in service of
adoption and developer outcomes.

---

## 3. Mental model

```text
                 ┌─────────────────────────────────────────┐
                 │   The platform product loop             │
                 │                                         │
  Discover  ───► │  developer pain (interviews, journeys)  │
     ▲           │          │                              │
     │           │          ▼                              │
     │           │  Prioritize (pain × frequency × reach)  │
     │           │          │                              │
     │           │          ▼                              │
     │           │  Build the thinnest thing that helps    │
     │           │          │                              │
     │           │          ▼                              │
  Measure  ◄──── │  Adoption, time-to-prod, DORA, NPS      │
                 └─────────────────────────────────────────┘
         (then feed the measurement back into discovery)
```

Say it to yourself before any platform decision: **Who is the customer, what job
are they hiring us for, and how will we know if they adopted it?**

---

## 4. Minimal implementation

The smallest useful artifact of product thinking is a **one-page Platform Product
Brief** — the platform equivalent of a product one-pager. It forces clarity before
anyone writes code:

```text
┌────────────────────────── Platform Product Brief ──────────────────────────┐
│ Problem statement      One or two sentences of real, evidenced pain.        │
│ Target persona         Who specifically is this for? (be narrow)            │
│ Jobs to be done        2–4 JTBD statements ("When…, I want…, so I can…")    │
│ Initial capabilities   The 3 smallest things that serve those jobs.         │
│ Success metrics        How you'll know it worked (adoption, time-to-prod…). │
│ Anti-goals             What this platform will deliberately NOT do.         │
└─────────────────────────────────────────────────────────────────────────────┘
```

The **anti-goals** line is the secret weapon. Stating what you *won't* do keeps the
platform thin, sets expectations, and prevents scope creep. "We will not support
every language on day one. We will not replace your IDE. We will not manage
stateful databases yet." Saying no is a product skill.

You'll write a real one in the lab.

---

## 5. Hands-on lab

Turn the pain you discovered in Module 01.1 into a crisp plan. You'll write a
one-page **Platform Product Brief**: problem, persona, jobs to be done, three
initial capabilities, success metrics, and — crucially — anti-goals.

➡️ **[Start the lab: Platform Product Brief](./lab/README.md)**

---

## 6. Production considerations

- **Publish the roadmap.** A visible, developer-influenced roadmap builds trust and
  invites the feedback that keeps you aligned. A secret roadmap breeds suspicion.
- **Run the platform like a product team.** Office hours, a changelog, release
  notes, a support channel, and a way to request and vote on features.
- **Instrument adoption from day one.** You can't improve what you don't measure.
  Decide *how* you'll measure "% on the golden path" before you ship v1.
- **Baseline before you build.** Measure time-to-first-deploy and DORA *before* the
  platform exists, so you can prove impact later.
- **Beware the captive-audience illusion.** If leadership mandates your tool,
  actively seek honest signal (anonymous surveys, real adoption depth) — compliance
  is not satisfaction.
- **Deprecate deliberately.** When you replace a v1 capability, provide a migration
  path. Breaking your customers erodes the trust adoption depends on.

---

## 7. Common mistakes

- **"Build it and they will come."** The original sin. No discovery, no customer,
  no adoption. *Fix:* start from evidenced pain; write the brief before the code.
- **Feature factory.** Measuring success by features shipped rather than outcomes.
  *Fix:* tie every initiative to a job and an adoption metric.
- **Solving your own problems, not theirs.** Building the elegant system *you* want
  to build. *Fix:* JTBD keeps the customer's outcome central.
- **No anti-goals → scope creep.** Trying to serve everyone instantly, ending up
  serving no one well. *Fix:* narrow persona, explicit anti-goals.
- **Building commodities.** Hand-rolling a metrics store or a CI runner. *Fix:* buy
  the commodity; build the opinionated glue.
- **Vanity metrics.** Reporting activity (pipeline runs) as success. *Fix:* adoption,
  time-to-prod, DORA, NPS.
- **Gatekeeper reflex.** "Just file a ticket and we'll do it." *Fix:* design for
  self-service; a ticket is a bug in the product.

---

## 8. Assessment

**Knowledge checks**

1. Rewrite this feature request as a Job to be Done: *"Developers need a button to
   roll back a deployment."*
2. Why is **adoption** considered the north-star metric for a platform?
3. Give one capability you'd almost always **buy/adopt** rather than build, and one
   you'd **build** thinly. Why?
4. What is an **anti-goal**, and why does stating anti-goals make a platform
   stronger?

**Concept exercise**

> Explain "platform as a product" to a staff engineer who says, *"We're an internal
> team — we don't have customers, we have requirements."* Make the case in a few
> sentences.

**Trade-off exercise**

> Your survey shows 95% of teams "use" the platform, but it's mandated and the NPS
> is deeply negative. Is the platform succeeding? What would you investigate, and
> what might high-usage-but-low-satisfaction be telling you?

<details>
<summary>Discussion</summary>

- **Q1:** e.g. *"When a deploy goes wrong, I want to return to the last known-good
  version in seconds, so I can stop the bleeding before investigating."* (The
  "button" is one solution; the job is fast, safe recovery.)
- **Q2:** A platform only delivers value when used; low adoption means the cognitive
  load wasn't actually reduced, regardless of features. Adoption also validates that
  you solved a real problem.
- **Q3:** Buy: metrics storage, CI runners, secret managers (commodities). Build:
  the golden-path service template / paved-road pipeline (your org-specific
  opinion). Differentiation lives in the glue.
- **Q4:** An anti-goal is something you explicitly won't do. It keeps scope thin,
  sets expectations, and prevents the platform from sprawling into a mediocre
  everything-tool.
- **Trade-off:** High usage + negative NPS = people comply but resent it; they'll
  route around you the moment they can, and you've lost the honest signal you need.
  Investigate *depth* of adoption (are they using the paved road or fighting it?),
  the specific friction, and whether the mandate is masking a product that isn't
  actually better than the alternative.

</details>

---

## 9. Further reading

- Anthony Ulwick / Clayton Christensen — Jobs to be Done
  ([jobs-to-be-done overview](https://jobs-to-be-done.com/))
- DORA — [research program and metrics](https://dora.dev/)
- Nicole Forsgren, Jez Humble, Gene Kim — *Accelerate* (the DORA metrics, in depth)
- Humanitec / PlatformEngineering.org — [platform product management resources](https://platformengineering.org/)
- Marty Cagan — *Inspired* (product discovery and product teams)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [01.1 — What Is Platform Engineering?](../01-what-is-platform-engineering/)
· _Next:_ [01.3 — Developer Experience →](../03-developer-experience/)
