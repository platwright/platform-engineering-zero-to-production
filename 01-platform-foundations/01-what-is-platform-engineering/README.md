# Module 01.1 — What Is Platform Engineering?

> Platform engineering is the discipline of building and operating **internal
> products that enable software teams to deliver software with less friction and
> lower cognitive load**. This module defines the field from first principles,
> places it against DevOps and SRE, and explains why so many platforms fail.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** nothing but [Module 00 · Orientation](../../00-orientation/). No tools, no cloud.

## Learning objectives

By the end of this module you will be able to:

- Explain the **cognitive load crisis** that makes platform engineering necessary.
- Trace the evolution from **Ops → DevOps → Platform Engineering** and say *why*
  each step happened.
- Define platform engineering as **building internal products**, and distinguish it
  from DevOps and SRE.
- Apply the **Thinnest Viable Platform (TVP)** principle.
- Name the most common reasons platforms fail and how to avoid them.

---

## 1. Concept

### The cognitive load crisis

Modern software delivery asks an application developer to know an astonishing
amount *beyond their actual application*:

```text
To ship one simple service to production, a developer may need to understand:

  Docker · Kubernetes · Helm · kubectl · YAML · Ingress/Gateway · TLS certs ·
  Terraform · cloud IAM · VPCs · CI/CD pipelines · OIDC · image scanning ·
  secret management · Prometheus · Grafana · log aggregation · on-call ·
  network policies · RBAC · resource requests/limits · autoscaling · DNS …
```

None of that is the business logic they were hired to write. It's **extraneous
cognitive load** — mental effort spent on the environment rather than the problem.

*Team Topologies* (Skelton & Pais) names three kinds of cognitive load:

- **Intrinsic** — effort inherent to the task (e.g. the domain logic itself).
  You want developers spending here.
- **Extraneous** — effort imposed by the environment and toolchain (how to deploy,
  how to wire up TLS, which fourteen YAML files to copy). You want to **eliminate**
  this.
- **Germane** — effort that builds useful, lasting understanding.

When extraneous load grows unbounded, delivery slows, mistakes multiply, the "it
works on my machine" gap widens, and your best engineers spend their days on
plumbing. **Platform engineering exists to cap and reduce extraneous cognitive
load** so stream-aligned teams can focus on delivering value.

### How we got here: Ops → DevOps → Platform Engineering

```text
         Siloed Ops                DevOps                 Platform Engineering
  ┌──────────────────┐   ┌──────────────────────┐   ┌──────────────────────────┐
  │ Devs throw code  │   │ "You build it,       │   │ A platform team builds a  │
  │ "over the wall"  │   │  you run it."        │   │ self-service product so   │
  │ to an Ops team   │   │ Devs own ops too —   │   │ every team can build and  │
  │ that deploys it. │   │ but now carry ALL    │   │ run it WITHOUT carrying   │
  │                  │   │ the operational load.│   │ all the operational load. │
  └──────────────────┘   └──────────────────────┘   └──────────────────────────┘
     slow, low         │  fast, but cognitive    │  fast AND sustainable:
     ownership         │  overload at scale      │  load is abstracted, not dumped
```

- **Siloed Ops.** Developers wrote code; a separate operations team ran it. Clear
  separation, but slow feedback, weak ownership, and constant hand-off friction.
- **DevOps.** The movement tore down the wall: *"you build it, you run it."* Teams
  gained ownership and speed. But taken literally at scale, DevOps **dumped** all
  operational concerns onto every product team. Each team re-solved deployment,
  observability, and security from scratch. Cognitive load exploded.
- **Platform Engineering.** The maturation of DevOps. Instead of every team
  re-inventing (or every team filing tickets to a central Ops team), a **platform
  team** builds a reusable, self-service **internal product** that abstracts the
  operational complexity. Teams keep ownership and speed, but no longer carry the
  full weight of the toolchain.

> Platform engineering is **not** a return to siloed Ops with a new name. The
> distinction is *self-service*: a platform offers capabilities teams consume on
> demand, not a queue of tickets a central team processes.

### A working definition

> **Platform engineering** is the discipline of designing, building, and operating
> internal developer platforms — reusable, self-service products — that reduce the
> cognitive load on software teams and let them deliver and operate software
> safely, reliably, and quickly.

Two words carry the weight:

- **Internal** — your customers are your own engineers, not external users.
- **Product** — it is built, supported, versioned, documented, and *adopted by
  choice*, not decreed. (Module 01.2 unpacks this.)

The CNCF *Platform Engineering* and *Platforms White Paper* work frames a platform
as a **foundation of self-service APIs, tools, services, knowledge, and support,
arranged as a compelling internal product.** Note the emphasis: not just tools —
also *knowledge* and *support*, packaged as a product.

---

## 2. Why it matters for platform engineering

This is the first module, so "why it matters" is really "why this whole field
matters":

- **Speed at scale.** Without a platform, delivery speed decays as you add teams
  and services — each one re-solves the same problems. A platform makes the Nth
  team nearly as fast as the first.
- **Reliability and security become structural.** When good practice is baked into
  a paved road (signed images, non-root containers, sane defaults, observability
  pre-wired), you get it *by default* instead of relying on every team to remember.
- **Leverage.** A small platform team can multiply the output of hundreds of
  developers. That leverage is the entire economic case for platform engineering.
- **Retention and focus.** Engineers do their best work on the problem they were
  hired for, not on YAML archaeology.

Industry adoption reflects this: platform engineering moved from "emerging" to
mainstream across recent CNCF and industry surveys, with a large majority of
medium-and-large organizations running or building internal platform teams. The
demand for engineers who can do this well — not just operate tools, but *build the
product* — is why this course exists.

---

## 3. Mental model

Hold these three models in your head for the rest of the course:

**1. The platform is a product; developers are its customers.**
If customers don't adopt it, it has failed — no matter how elegant the
architecture. Adoption is the scoreboard.

**2. The platform's job is to move cognitive load, not dump it.**

```text
Without a platform                 With a platform
─────────────────                  ───────────────
every team carries:                the platform team carries the hard parts once;
  all the ops complexity           every team consumes a simple, safe interface
  (high extraneous load,           (low extraneous load, focus on the product)
   re-solved N times)
```

**3. The Thinnest Viable Platform (TVP).**
You do **not** build a giant platform up front. You build the *thinnest* thing that
removes real, observed developer pain — which might start as a well-written wiki
page and a shell script — and you grow it **by demand**, as real usage reveals the
next most valuable capability.

```text
TVP evolution (driven by demand, not ambition):

  A documented golden path (wiki + script)
        → a reusable CI template
            → a self-service "create a service" command
                → a portal that ties it together
                    → … only as each step earns its place
```

> A platform is never "done." It's a product with a roadmap, grown toward the pain
> that developers actually feel.

---

## 4. Minimal implementation

Let's make the "platform as a product" idea concrete with the smallest possible
example. Imagine the pain you keep hearing from teams is: *"Setting up a new
service's deployment takes two days of copying YAML from another repo and hoping."*

A **Thinnest Viable Platform** response is **not** "let's stand up Backstage." It's:

```text
platform/
├── README.md               # the golden path, written down: "To create a service…"
├── templates/
│   └── service/            # a known-good starter: Dockerfile, manifests, CI
└── new-service.sh          # a script that stamps out the template for you
```

```bash
# The entire "platform" interface, v0.1:
./new-service.sh --name payments --owner team-payments
# → creates a repo from the template, pre-wired with a working Dockerfile,
#   a deployment manifest with sane defaults, and a CI pipeline.
```

That's it. It is boring, and that is the point. It:

- removes a real, observed pain (two days → two minutes),
- encodes good defaults *once* (so every service starts secure and observable),
- is a **product** with a clear interface (`new-service.sh`), and
- can grow — the script becomes a service, the template becomes a catalog, the
  README becomes a portal — *only when demand justifies it*.

Everything you build later in this course (Helm, GitOps, Backstage golden paths)
is a more powerful version of this same move: **encode the paved road once, let
teams consume it on demand.**

---

## 5. Hands-on lab

Your first platform skill isn't technical — it's **product discovery**. You can't
build a platform people want until you understand the pain they feel. In the lab,
you'll interview three engineers about the most painful part of deploying and
operating their service, and find the recurring themes.

➡️ **[Start the lab: Developer Pain Discovery](./lab/README.md)**

---

## 6. Production considerations

What separates a toy "platform" from one a real organization depends on:

- **Adoption is the metric that matters.** A beautiful platform with 10% adoption
  is a failure; a plain one with 90% adoption is a success. Track adoption from
  day one (what % of teams/services use the golden path?).
- **Support is part of the product.** A platform without docs, a support channel,
  and someone who answers questions is a liability. "Knowledge and support" are in
  the definition for a reason.
- **Escape hatches.** Real platforms let teams deviate when they genuinely need to.
  A platform that *forces* one way for every case becomes a bottleneck people route
  around. Opinionated defaults, not mandatory cages.
- **Versioning and migration.** Golden paths change. You need a way to move teams
  from v1 to v2 without breaking them — a product-management concern, not just an
  engineering one.
- **It's never finished.** Budget for ongoing operation, a roadmap, and iteration,
  not a one-time "platform project."

---

## 7. Common mistakes

Most platform failures are variations on a few themes:

- **Built without developer feedback ("build it and they will come").** The team
  builds what *it* finds interesting, ships it, and is surprised when no one
  adopts it. *Fix:* start from observed pain (this module's lab) and keep a tight
  feedback loop.
- **Over-engineered up front.** Boiling the ocean with a giant platform before any
  real usage exists. Months of work, little value, high maintenance. *Fix:* TVP —
  grow by demand.
- **Under-adopted / forced adoption.** Either no one uses it, or it's mandated and
  resented. Both signal a product that isn't actually better than the alternative.
  *Fix:* make the paved road the *easiest* path, not the *mandatory* one.
- **A ticket system with a nicer logo.** The "portal" just files tickets a human
  processes. That's not self-service; it's siloed Ops in disguise. *Fix:* real
  self-service APIs/automation behind the interface.
- **Tool-first thinking.** "We adopted Kubernetes/Backstage, therefore we do
  platform engineering." Tools are not a platform; a *product that reduces
  cognitive load* is. *Fix:* lead with the problem and the customer.
- **Confusing platform engineering with pure Ops centralization.** Pulling all
  operational work back into one team that everyone depends on recreates the
  bottleneck. *Fix:* enable, don't gatekeep (Module 01.5).

---

## 8. Assessment

**Knowledge checks**

1. What are the three types of cognitive load, and which one is platform
   engineering primarily trying to reduce?
2. In one sentence, how does platform engineering differ from "you build it, you
   run it" DevOps?
3. What does the Thinnest Viable Platform principle tell you to do *instead* of a
   big up-front platform build?
4. Why is a portal that just files tickets *not* a platform?

**Concept exercise**

> Explain what platform engineering achieves **without using the words
> "Kubernetes," "Backstage," or "self-service."** (Force yourself to describe the
> outcome, not the tools.)

**Trade-off exercise**

> A director says: "We'll adopt Kubernetes and Backstage next quarter — that's our
> platform strategy." What's wrong with framing it that way, and what two questions
> would you ask before writing any code?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Intrinsic, extraneous, germane. Platform engineering targets
  **extraneous** load (and ideally frees capacity for intrinsic/germane).
- **Q2:** DevOps gives teams ownership *and* all the operational load; platform
  engineering keeps the ownership but **abstracts** the load behind a self-service
  product instead of dumping it on every team.
- **Q3:** Build the thinnest thing that removes a real, observed pain, and grow it
  by demand — not a grand platform no one asked for yet.
- **Q4:** Because self-service means a human isn't in the loop for routine requests;
  a ticket queue is the bottleneck platform engineering is meant to remove.
- **Trade-off:** It's tool-first and skips the product. Better questions: *What
  developer pain are we solving, and for whom?* and *How will we know if it's
  adopted?* Tools are an implementation detail chosen after the problem is clear.

</details>

---

## 9. Further reading

- CNCF — [*Platforms White Paper* (CNCF TAG App Delivery)](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
- CNCF — [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)
- Matthew Skelton & Manuel Pais — [*Team Topologies*](https://teamtopologies.com/) (cognitive load, platform-as-a-service)
- Humanitec — [Platform Engineering resources](https://platformengineering.org/) and the community at <https://platformengineering.org/slack>
- Martin Fowler — ["The State of Platform Engineering" and related articles](https://martinfowler.com/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [01 · Platform Foundations](../README.md)
· _Next:_ [Module 01.2 — Platform as a Product →](../02-platform-as-a-product/)
