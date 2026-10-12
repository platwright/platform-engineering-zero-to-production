# Interview Prep — Platform Engineering Fundamentals

> This domain tests whether you can explain *why* platform engineering exists
> before reaching for a tool. Interviewers want the product mindset — cognitive
> load, golden paths, self-service, and adoption — not a recital of Kubernetes
> features. Practice each answer out loud, and try to define the idea **without**
> naming a single product first; then open the model answer and check yourself.

## Core definitions

### Q: What is platform engineering?

**What they're really asking:** Can you define the field as a product discipline, not a pile of tools?

Platform engineering is the discipline of building and operating an **internal
product** — a reusable, self-service platform — that lets software teams deliver
and run software with less friction and lower cognitive load. Two words carry the
weight: **internal** (your customers are your own engineers) and **product** (it is
versioned, supported, documented, and adopted by choice, not decree).

- It exists to **cap and reduce extraneous cognitive load** so stream-aligned teams spend their time on business logic.
- The CNCF frames a platform as a *foundation of self-service APIs, tools, services, knowledge, and support, arranged as a compelling internal product* — knowledge and support are part of it, not just tooling.
- Adoption is the scoreboard: an elegant platform nobody uses has failed.

**Going deeper:** [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/)

**Red flags:** "It's our Kubernetes and Backstage setup." Equating a tool with the platform, or describing a central team that just processes tickets.

### Q: How does platform engineering differ from DevOps and SRE?

**What they're really asking:** Do you understand the evolution and the division of responsibility?

DevOps tore down the wall between dev and ops — *"you build it, you run it"* —
giving teams ownership and speed. Taken literally at scale, it **dumped** every
operational concern (deploys, observability, security) onto each product team, so
cognitive load exploded. Platform engineering is the maturation: a platform team
**abstracts** that complexity behind a self-service product so teams keep ownership
*without* carrying the whole toolchain. SRE is a reliability discipline — SLOs,
error budgets, toil reduction — and is complementary: platform teams apply SRE
practices to the platform itself, and ship SRE capabilities (SLOs, pre-wired
observability) as paved-road defaults.

- DevOps is culture and ownership; platform engineering is the product that makes that ownership sustainable at scale.
- SRE is reliability engineering; it runs *on* the platform and *inside* the platform team.

**Going deeper:** [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/) and [17 · Platform SRE](../17-platform-sre/)

**Red flags:** "It's just a new name for DevOps or Ops." Missing the self-service product distinction.

### Q: What is an Internal Developer Platform (IDP)?

**What they're really asking:** Can you describe the thing a platform team actually builds?

An IDP is the self-service layer developers use to provision, deploy, and operate
their software without filing tickets or learning every underlying tool. It is
usefully described as **five planes** stitched together by an orchestration layer:

- **Developer control plane** — the interfaces developers touch (portal, CLI, a repo with a manifest).
- **Integration and delivery plane** — CI/CD and GitOps that build and ship.
- **Resource plane** — clusters, databases, queues (often via Terraform/Crossplane).
- **Monitoring plane** — metrics, logs, traces, SLOs wired in by default.
- **Security plane** — identity, RBAC, policy, secrets.

The orchestration layer fans a single request ("I need a service with a Postgres")
across those planes so they act as one system.

**Going deeper:** [01.4 · The Internal Developer Platform](../01-platform-foundations/04-the-internal-developer-platform/) and [15.1 · IDP Architecture](../15-developer-experience-and-idp/01-idp-architecture/)

### Q: What is cognitive load, and why does it matter in platform engineering?

**What they're really asking:** Do you know the core problem the whole field is organized around?

*Team Topologies* names three kinds of cognitive load: **intrinsic** (the domain
problem itself — you want devs here), **extraneous** (effort imposed by the
toolchain and environment), and **germane** (effort that builds lasting
understanding). When extraneous load grows unbounded — Docker, Kubernetes, Helm,
TLS, IAM, Prometheus, on-call — delivery slows and your best engineers spend their
days on plumbing. **Platform engineering exists to cap and reduce extraneous load**
by moving the hard parts into the platform once, so every team consumes a simple,
safe interface.

**Going deeper:** [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/) and [01.3 · Developer Experience](../01-platform-foundations/03-developer-experience/)

### Q: What is a golden path?

**What they're really asking:** Can you distinguish the paved road from a mandate?

A golden path is the **supported, opinionated, well-documented way** to do a common
task — create a service, add a database, ship to production — with good defaults
(secure base image, resource limits, observability, CI) baked in. It is the
*easiest* path, not the *only* path: teams get speed and safety by default but can
step off the path when they genuinely need to. The goal is to make the right thing
the easy thing.

- Encodes good practice once, so every new service starts secure and observable.
- Paired with **escape hatches** so it enables rather than cages.

**Going deeper:** [15.6 · Golden Paths](../15-developer-experience-and-idp/06-golden-paths/)

**Red flags:** Describing a golden path as a hard mandate with no escape hatch, or confusing it with a one-off template nobody maintains.

## The platform-as-a-product mindset

### Q: What does "platform as a product" actually mean?

**What they're really asking:** Do you treat developers as customers and adoption as the metric?

It means applying product management to an internal platform: you have **customers**
(your engineers), you do **discovery** (understand their real pain before building),
you have a **roadmap**, you **version and migrate**, and you measure **adoption and
satisfaction** rather than shipping features nobody asked for. A platform mandated
from above but unloved is a failure; one adopted by choice because it is genuinely
the easiest path is a success.

- Support and documentation are part of the product, not an afterthought.
- Adoption is the scoreboard — track the percentage of teams and services on the paved road.

**Going deeper:** [01.2 · Platform as a Product](../01-platform-foundations/02-platform-as-a-product/)

**Red flags:** "We built it, so teams must use it." Build-it-and-they-will-come with no discovery or feedback loop.

### Q: What is the Thinnest Viable Platform (TVP)?

**What they're really asking:** Do you avoid boiling the ocean and grow by demand?

TVP says you do **not** build a giant platform up front. You build the *thinnest*
thing that removes a real, observed developer pain — which might start as a
well-written wiki page plus a shell script — and grow it **by demand** as real usage
reveals the next most valuable capability. A documented golden path becomes a
reusable CI template, becomes a "create a service" command, becomes a portal — each
step only when it earns its place.

**Going deeper:** [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/)

**Red flags:** Proposing Backstage plus a full control plane on day one before any adoption or observed pain exists.

### Q: Golden paths versus guardrails — what is the difference?

**What they're really asking:** Do you know the two complementary mechanisms of a paved road?

A **golden path** is the easy, opinionated way to do something (pull-based: teams
*choose* it because it is the least-effort route). A **guardrail** is an enforced
boundary that stops dangerous outcomes regardless of path (push-based: admission
policy, OPA/Kyverno, RBAC, network policy). Good platforms combine them: make the
safe path the easy path (golden path), and backstop it with guardrails so mistakes
are caught even off the path. Guardrails should block the catastrophic and warn on
the merely risky, not nitpick.

**Going deeper:** [15.6 · Golden Paths](../15-developer-experience-and-idp/06-golden-paths/) and [13.3 · Policy as Code with Kyverno](../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/)

### Q: Why do so many platforms fail?

**What they're really asking:** Have you seen the common failure modes and their fixes?

Most platform failures are variations on a few themes:

- **Built without developer feedback** — the team builds what it finds interesting and is surprised when nobody adopts it. *Fix:* start from observed pain, keep a tight feedback loop.
- **Over-engineered up front** — months of work, little value, high maintenance. *Fix:* TVP, grow by demand.
- **Forced adoption** — mandated and resented, so teams route around it. *Fix:* make the paved road the easiest path, not the mandatory one.
- **A ticket system with a nicer logo** — the "portal" just files tickets a human processes. *Fix:* real self-service automation behind the interface.
- **Tool-first thinking** — "we adopted Kubernetes, therefore we do platform engineering." *Fix:* lead with the problem and the customer.

**Going deeper:** [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/) and [20.1 · Platform Engineering Maturity Model](../20-advanced-platform-topics/01-platform-engineering-maturity-model/)

## Operating model and success

### Q: What team topology does a platform team use, and how does it avoid becoming a bottleneck?

**What they're really asking:** Do you know *Team Topologies* and the enabling-versus-gatekeeping distinction?

In *Team Topologies* a **platform team** provides a self-service platform that
reduces the cognitive load of **stream-aligned teams**. It avoids becoming a
bottleneck by offering **capabilities consumed on demand** rather than a queue of
work it must process. When a team needs hands-on help, the platform team acts in an
**enabling** mode — pairing to raise capability — then steps back. The failure mode
is recentralizing all operational work into one team everyone depends on, which
recreates siloed Ops.

**Going deeper:** [01.5 · Platform Team Topology](../01-platform-foundations/05-platform-team-topology/)

**Red flags:** A platform team that gatekeeps every deployment, or one with no interface except "open a ticket."

### Q: Why is self-service the defining property of a platform?

**What they're really asking:** Do you understand what separates a platform from a central Ops queue?

Self-service means a human is **not** in the loop for routine requests: a developer
provisions an environment, ships a service, or adds a database through an API,
command, or merge — not by waiting on another team. That is the distinction from
siloed Ops with a new logo. Self-service is what delivers the economic case for
platforms: a small platform team multiplies the output of hundreds of developers
because the Nth request costs the platform team nothing.

**Going deeper:** [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/) and [15.1 · IDP Architecture](../15-developer-experience-and-idp/01-idp-architecture/)

### Q: How do you measure the success of a platform?

**What they're really asking:** Do you measure outcomes, not output?

Measure the platform like a product, across a few dimensions:

- **Adoption** — percentage of teams and services on the golden path; this is the headline metric.
- **Delivery outcomes** — DORA metrics (deployment frequency, lead time, change-failure rate, time to restore) for teams on the platform versus off it.
- **Developer experience** — satisfaction and friction surveys, time-to-first-deploy for a new service, and SPACE-style signals.
- **Reliability and cost** — platform SLOs and the cost per team or per service the platform enables.

The anti-pattern is counting features shipped or tickets closed; those are output, not the outcomes the platform exists to improve.

**Going deeper:** [20.3 · Platform Engineering Metrics](../20-advanced-platform-topics/03-platform-engineering-metrics/) and [01.3 · Developer Experience](../01-platform-foundations/03-developer-experience/)

**Red flags:** Vanity metrics (lines of YAML, number of clusters) with no link to developer or business outcomes.
