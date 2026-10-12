# Interview Prep — Developer Experience and IDP

> This domain tests whether you can treat the platform as a product and measure
> whether it actually helps developers. Interviewers probe cognitive load, golden
> paths versus guardrails, DORA and SPACE, the five IDP planes, and Backstage.
> Practice framing answers around **developer outcomes and adoption**, not tools,
> then check the model answer.

## Developer experience foundations

### Q: What is developer experience (DX), and why measure it?

**What they're really asking:** Do you see DX as the core product outcome of a platform?

Developer experience is how it *feels* to build, ship, and operate software on your
platform — the friction, feedback speed, and cognitive load along the path to
production. You measure it because DX is the platform's reason to exist: better DX
means faster delivery, fewer errors, and higher retention. If you cannot measure it,
you are guessing whether the platform helps. Measure with a mix of **flow metrics**
(lead time, time-to-first-deploy) and **perception** (satisfaction, friction surveys).

**Going deeper:** [01.3 · Developer Experience](../01-platform-foundations/03-developer-experience/)

**Red flags:** Treating DX as "nice to have" or measuring only tool usage, not developer sentiment and flow.

### Q: What is cognitive load, and how does a platform reduce it?

**What they're really asking:** Do you know the core problem and the mechanism of relief?

*Team Topologies* splits cognitive load into **intrinsic** (the domain problem),
**extraneous** (toolchain and environment overhead), and **germane** (useful learning).
A platform's job is to cut **extraneous** load by solving the hard operational parts
**once** and exposing a simple, safe interface — a golden path — so developers spend
their limited working memory on the product, not on fourteen YAML files and TLS
plumbing.

**Going deeper:** [01.3 · Developer Experience](../01-platform-foundations/03-developer-experience/) and [01.1 · What Is Platform Engineering?](../01-platform-foundations/01-what-is-platform-engineering/)

### Q: Golden paths versus guardrails — what is the difference?

**What they're really asking:** Do you know the two complementary ways to shape behavior?

A **golden path** is the easy, opinionated, supported way to do a task — a **pull**:
teams choose it because it is the least-effort route, with good defaults baked in. A
**guardrail** is an enforced boundary that prevents dangerous outcomes regardless of
path — a **push**: admission policy, RBAC, NetworkPolicy. Good platforms combine them:
make the safe path the easy path, and backstop it with guardrails that block the
catastrophic while merely warning on the risky. Guardrails should not nitpick.

**Going deeper:** [15.6 · Golden Paths](../15-developer-experience-and-idp/06-golden-paths/) and [13.3 · Policy as Code with Kyverno](../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/)

**Red flags:** Only guardrails (a wall of "no") with no easy paved path, or a golden path with no safety backstop.

## Measuring delivery and experience

### Q: What are the DORA metrics, and what are their limits?

**What they're really asking:** Do you know the industry delivery metrics and how to use them well?

The four DORA metrics measure software **delivery performance**:

- **Deployment frequency** and **lead time for changes** — throughput.
- **Change failure rate** and **time to restore service** — stability.

Throughput and stability move **together** in high performers, countering the "fast
means fragile" myth. Limits: DORA measures delivery, not developer happiness or the
value delivered; it is easy to game at the team level; and it should drive
conversation and trends, not individual performance reviews. Pair it with experience
signals.

**Going deeper:** [20.3 · Platform Engineering Metrics](../20-advanced-platform-topics/03-platform-engineering-metrics/)

**Red flags:** Using DORA to rank individuals, or chasing deploy frequency while ignoring change failure rate.

### Q: What is the SPACE framework, and why use it alongside DORA?

**What they're really asking:** Do you understand productivity is multi-dimensional?

**SPACE** captures developer productivity across five dimensions —
**S**atisfaction and well-being, **P**erformance, **A**ctivity, **C**ommunication and
collaboration, and **E**fficiency and flow — precisely because no single metric (like
activity or commit count) tells the truth. Used with DORA, SPACE adds the **human**
and **flow** side: a team can deploy often yet be miserable and interrupted. Choose a
few metrics across dimensions rather than optimizing one.

**Going deeper:** [20.3 · Platform Engineering Metrics](../20-advanced-platform-topics/03-platform-engineering-metrics/) and [01.3 · Developer Experience](../01-platform-foundations/03-developer-experience/)

**Red flags:** Equating activity (commits, PRs) with productivity.

## IDP architecture and Backstage

### Q: What are the five planes of an Internal Developer Platform?

**What they're really asking:** Can you describe an IDP as planes connected by orchestration?

An IDP is five planes stitched together by an **orchestration layer**:

- **Developer control plane** — the interfaces developers use (portal, CLI, a manifest in a repo).
- **Integration and delivery plane** — CI/CD and GitOps that build and ship.
- **Resource plane** — clusters, databases, queues (often via Terraform/Crossplane).
- **Monitoring plane** — metrics, logs, traces, SLOs, wired in by default.
- **Security plane** — identity, RBAC, policy, and secrets.

No single plane satisfies "I need a service with a Postgres"; the **orchestration
layer** fans one request across the planes so they act as one system.

**Going deeper:** [15.1 · IDP Architecture](../15-developer-experience-and-idp/01-idp-architecture/) and [01.4 · The Internal Developer Platform](../01-platform-foundations/04-the-internal-developer-platform/)

### Q: What does the orchestration layer do, and why can no single plane replace it?

**What they're really asking:** Do you understand the glue that makes an IDP one system?

The orchestration layer takes a single developer intent — expressed as one manifest or
portal action — and **sequences** the planes to fulfill it: scaffold the repo and
pipeline (delivery), provision the Postgres (resource), wire dashboards and SLOs
(monitoring), and set RBAC, policy, and secrets (security). No single plane can do
this because the request **spans** all of them; the orchestration layer holds the
platform's **opinion** about how they combine, and lets you swap any underlying tool
without changing the developer interface.

**Going deeper:** [15.1 · IDP Architecture](../15-developer-experience-and-idp/01-idp-architecture/)

### Q: What is platform-as-a-product, and how does it apply to an IDP?

**What they're really asking:** Do you manage the IDP with product discipline?

It means running the IDP like a product: developers are **customers**, you do
**discovery** before building, keep a **roadmap**, **version and migrate** golden paths,
and measure **adoption and satisfaction**. An IDP mandated but unloved fails; one
adopted because it is genuinely the easiest path succeeds. Support, documentation, and
a feedback channel are part of the product, not extras.

**Going deeper:** [01.2 · Platform as a Product](../01-platform-foundations/02-platform-as-a-product/) and [15.8 · Developer Portal Documentation](../15-developer-experience-and-idp/08-developer-portal-documentation/)

**Red flags:** "We built it, they must use it." No discovery, no adoption metric, no support.

### Q: What is the Backstage software catalog?

**What they're really asking:** Do you know how a developer portal models the estate?

The Backstage **catalog** is a metadata inventory of everything you run, modeled as
**entities** — `Component` (a service or library), `API`, `System`, `Resource`, and the
owning `Group`/`User` — usually described by a `catalog-info.yaml` in each repo. It
answers "what do we have, who owns it, what does it depend on," powering ownership,
API discovery, and scorecards. The hard part is keeping it accurate, so catalog data
should be **ingested from source**, not hand-maintained.

**Going deeper:** [15.3 · Backstage Software Catalog](../15-developer-experience-and-idp/03-backstage-software-catalog/) and [15.2 · Backstage Fundamentals](../15-developer-experience-and-idp/02-backstage-fundamentals/)

### Q: What are Backstage software templates (the Scaffolder)?

**What they're really asking:** Do you know how a portal delivers golden paths as self-service?

Software templates are Backstage's **Scaffolder** turning a golden path into a
self-service action: a developer fills a form, and the template runs steps —
**fetch** a skeleton, **publish** a new repo pre-wired with a Dockerfile, CI, manifests,
and ownership, then **register** it in the catalog. This is the TVP "create a service"
script, productized: good defaults encoded once, consumed on demand, so a new service
starts secure, observable, and compliant.

**Going deeper:** [15.4 · Backstage Software Templates](../15-developer-experience-and-idp/04-backstage-software-templates/) and [15.6 · Golden Paths](../15-developer-experience-and-idp/06-golden-paths/)

**Red flags:** A portal that only files tickets, or templates nobody maintains so they drift from current best practice.

### Q: What is the difference between a developer portal and a platform?

**What they're really asking:** Do you know a portal is a UI, not the platform itself?

A **portal** (like Backstage) is the **developer control plane** — a UI and catalog
that surfaces the platform. The **platform** is the whole system behind it: the
delivery, resource, monitoring, and security planes with real self-service automation.
A pretty portal in front of manual ticket-driven Ops is **not** a platform — it is
siloed Ops with a nicer logo. The portal must trigger real automation.

**Going deeper:** [15.1 · IDP Architecture](../15-developer-experience-and-idp/01-idp-architecture/) and [15.2 · Backstage Fundamentals](../15-developer-experience-and-idp/02-backstage-fundamentals/)

**Red flags:** Equating "we installed Backstage" with "we have a platform."
