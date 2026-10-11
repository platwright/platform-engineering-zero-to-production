# Module 15.1 — IDP Architecture

> In [Module 01.4](../../01-platform-foundations/04-the-internal-developer-platform/)
> you learned the **five planes** of an IDP as a map. This module turns the map into a
> buildable architecture: how the planes connect through an **orchestration layer**,
> how to design the **platform API** that is the real product, the product principles
> that keep an IDP usable (convention over configuration, escape hatches, supported
> migration), and a **build-vs-buy decision matrix** you can actually fill in.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 01.3](../../01-platform-foundations/03-developer-experience/)
and [01.4](../../01-platform-foundations/04-the-internal-developer-platform/); the
mindset from [Projects 1–3](../../04-platform-project-01/).

## Learning objectives

By the end of this module you will be able to:

- Describe how the five planes connect through an **orchestration layer** and where
  your Project 1–3 work fits.
- Design a **platform API**: a stable, versioned, documented, declarative contract
  that every interface sits on top of.
- Apply the IDP product principles — **convention over configuration**, **escape
  hatches exist**, **migration supported**.
- Use a **build-vs-buy decision matrix** to choose components deliberately instead of
  by hype.

---

## 1. Concept

### From map to architecture

Module 01.4 gave you the five planes: **developer control**, **integration &
delivery**, **resource**, **monitoring**, and **security**. That is the *what*. This
module is the *how they connect*. An IDP is not five tools sitting next to each other;
it is five planes stitched together by an **orchestration layer** that turns one
developer request into coordinated action across all of them.

```text
Five planes (the WHAT, from 01.4)      This module adds the HOW:
  control · delivery · resource    →   a platform API + orchestration that
  monitoring · security                make the planes act as one system
```

### The orchestration layer

When a developer says *"I want a new Go service with a small Postgres in staging,"* no
single plane can satisfy that. Something has to:

- scaffold the repo from the golden-path template (control + delivery),
- open a GitOps PR to deploy it (delivery),
- provision the Postgres via IaC/Crossplane (resource),
- wire a default dashboard and alerts (monitoring),
- inject secrets and set least-privilege access (security).

The component that fans one request out across the planes is the **orchestration
layer** (Humanitec calls its product a *Platform Orchestrator*). You do not have to
buy one — across this course you assemble it from open-source pieces you already know:
a **template** (Backstage scaffolder, Module 15.4) triggers **CI** (Phase 6), which
commits to a **GitOps** repo (Phase 8) that ArgoCD reconciles, provisioning
**resources** (Phase 5 Terraform/Crossplane) and wiring **observability** (Phase 11).
The orchestration is the *glue and sequencing*, and it is where your platform's
opinion lives.

### The platform API is the product

The single most important architectural decision is the **platform API**: the stable,
versioned, declarative contract that describes *what a developer wants*, independent of
*how* it is fulfilled. Portals and CLIs are thin clients of it; the API is what
endures.

A good platform API is:

- **Declarative.** The developer states the desired end-state ("a service named
  `payments`, owner `team-payments`, needs a small Postgres in staging"), not the
  steps. This is the same shift GitOps made in Phase 8.
- **Stable and versioned.** It has consumers, so it is subject to the same rules as
  Module 06.4's pipeline template: semantic versions, deprecation over deletion, a
  migration path. Break it and you break every team.
- **Documented.** A schema with required/optional fields, defaults, and examples —
  rendered in the portal (Module 15.8).
- **Abstracted at the right level.** It exposes *workloads and their needs*, not raw
  Kubernetes. The open-source [Score](https://score.dev/) spec and Humanitec's
  workload model are examples of this "describe the workload, not the YAML" idea.

```yaml
# platform-request.yaml — a v1 platform API as a declarative spec
apiVersion: platform.example.com/v1
kind: ServiceRequest
metadata:
  name: payments
  owner: team-payments
spec:
  language: go
  path: go-microservice   # the golden path this service follows
  environments:
    - name: staging
      resources:
        - type: postgres
          size: small
```

Every interface — Backstage, the `platform` CLI (Module 15.7), a CI job — produces or
consumes *this*, and the orchestration behind it does the work. Design this contract
**before** you choose a portal.

### IDP product principles

Three principles separate an IDP developers *choose* from one they resent:

- **Convention over configuration.** The golden path encodes good defaults so the
  common case needs almost no input. A developer names a service and picks a team;
  non-root containers, SBOMs, dashboards, and sane resource limits come for free. The
  fewer decisions a developer must make to do the right thing, the better.
- **Escape hatches exist.** From Module 01.3: golden paths are the *easiest* route,
  not a mandatory cage. A sanctioned, documented, auditable way to deviate (a custom
  base image, a database the platform does not support yet) keeps teams on the
  platform instead of routing around it. An escape hatch you can see and count is far
  safer than a silent fork.
- **Migration is supported.** Golden paths and the API evolve. When v2 lands, v1 keeps
  working with a deprecation warning and a sunset date, and you provide tooling (a bot
  that opens the bump PR) to move teams. This is Module 06.4's versioning discipline
  applied to the whole platform.

### Build vs buy, deliberately

Module 01.4 surveyed the portal landscape (Backstage, Port, Cortex, Compass, custom).
The architecture question is sharper: for *each* component, do you build, buy, or
adopt open source? Decide with a **matrix**, not a vibe. Weigh, per component:

- **Differentiation** — does this encode *your* opinion (golden paths, orchestration)
  or is it a commodity (a catalog UI)? Build where you differentiate; buy commodities.
- **Operational cost** — can you run and upgrade it? Backstage is powerful but is a
  real application you must operate.
- **Time to value** — SaaS is faster to stand up; open source is cheaper per seat and
  more extensible.
- **Lock-in and exit** — how hard is it to leave? Favor open standards and an
  API-first core so the portal stays swappable.

The recurring heuristic: **buy the portal, build the paths.** Spend scarce engineering
on the orchestration and golden paths that are yours; do not reimplement a catalog UI.

---

## 2. Why it matters for platform engineering

This module is the blueprint for everything else in the phase — and for Project 4. If
you skip the architecture and jump straight to installing Backstage, you will build a
pretty portal over a pile of tickets (Module 01.4's number-one anti-pattern). Getting
the architecture right means:

- **The API outlives the UI.** You can swap Backstage for Port, add a CLI, or let CI
  consume the platform, all without re-plumbing — because they are clients of a stable
  contract.
- **Orchestration is your moat.** Any team can install a portal; few can make one
  request reliably provision, deploy, secure, and observe a service. That glue is the
  platform's actual value.
- **You choose components on purpose.** A filled-in build-vs-buy matrix is a decision
  you can defend to leadership, not a bandwagon you jumped on.

When you can sketch the planes, the orchestration, and the API for any platform — and
justify each build-vs-buy call — you are architecting an IDP, not assembling tools.

---

## 3. Mental model

```text
          DEVELOPER
             │  "I want a Go service + small Postgres in staging"
             ▼
   ┌───────────────────────────────┐
   │  INTERFACES (thin clients)     │  Backstage · platform CLI · CI
   └───────────────┬───────────────┘
                   ▼
   ┌───────────────────────────────┐
   │  PLATFORM API (the product)    │  declarative · versioned · documented
   │  ServiceRequest spec in Git    │
   └───────────────┬───────────────┘
                   ▼
   ┌───────────────────────────────┐
   │  ORCHESTRATION LAYER (the glue)│  sequences the planes; holds your opinion
   └───┬───────┬───────┬───────┬────┘
       ▼       ▼       ▼       ▼
   delivery  resource monitor security     ← the five planes (control = interfaces above)
   (GitOps)  (IaC/XP) (OTel/   (secrets/
             Grafana) policy)

Rule of thumb: design the API first, build the orchestration, treat every
interface as swappable, and buy the commodity planes while building your paths.
```

One sentence to carry: **an IDP is a stable platform API plus orchestration across the
five planes, exposed through interchangeable interfaces.**

---

## 4. Minimal implementation

The thinnest honest architecture is the `platform-request.yaml` above plus a sketch of
the orchestration that fulfills it — *no portal required yet*. Write the contract, then
list what each field triggers across the planes:

```text
spec.path: go-microservice        → control/delivery: scaffold repo from template
spec.language: go                 → delivery: select the Go CI pipeline (Phase 6)
spec.environments[].name: staging → delivery: GitOps App targets the staging cluster
spec.resources[].type: postgres   → resource: Crossplane/Terraform claim (Phase 5)
(always-on defaults)              → monitoring: default dashboard + alerts (Phase 11)
(always-on defaults)              → security: secret injection + least-privilege RBAC
```

Notice three things. First, the developer's interface is **one declarative file** —
exactly the shape of Module 01.4's minimal IDP, now with explicit API versioning.
Second, the **always-on defaults** (monitoring, security) are *convention*, not
developer choices — they are in the path by default, never bolted on. Third, every
trigger maps to work you already did in Projects 1–3; this phase is wiring a
self-service front end onto it. Add a CLI, then a portal, **only as demand justifies**
(the Thinnest Viable Platform).

---

## 5. Hands-on lab

You will design the architecture for a concrete IDP: draw the five planes and the
orchestration, write a **platform API spec** for a "new service" request, and fill in a
**build-vs-buy matrix** for each component. The deliverable is the architecture
document and API contract you will reference for the rest of the phase and Project 4.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Version the API from v1.** It has consumers the moment anyone uses it. Decide the
  schema, defaults, and deprecation policy before the second team adopts it.
- **Make the orchestration idempotent and observable.** Re-applying the same
  `ServiceRequest` must not create duplicates, and every fulfillment should emit
  events you can trace when a provision half-fails (which it will).
- **Design for partial failure.** Provisioning spans Git, CI, a cloud, and a cluster.
  Decide what happens when the repo is created but the database claim fails — roll
  back, retry, or surface a clear, actionable error. Silent half-states erode trust.
- **Keep security and monitoring in the path by default.** Retrofitting them per team
  leaves gaps. They are always-on conventions, not opt-in parameters.
- **Treat escape-hatch usage as a signal.** A frequently used hatch is a bug report
  about your defaults — change the path, do not just tolerate the workaround.
- **Document the contract where developers already are.** The API schema belongs in
  the portal (TechDocs, Module 15.8), versioned with the platform.

---

## 7. Common mistakes

- **UI-first instead of API-first.** Building the Backstage portal before the
  declarative contract, then being unable to automate against it or swap the UI.
  *Fix:* design and version the API spec first; the portal is one client.
- **No orchestration — a portal over tickets.** The "create" button files a ticket a
  human fulfills. That is Module 01.4's top anti-pattern. *Fix:* real automation that
  fans the request across the planes.
- **Configuration over convention.** A template with forty required fields reproduces
  the cognitive load you set out to remove. *Fix:* sensible defaults; ask only for
  what is genuinely service-specific.
- **No escape hatch, so teams fork.** Forbidding all deviation pushes teams off the
  platform silently, destroying your visibility. *Fix:* sanctioned, logged, counted
  hatches.
- **Breaking the API in place.** Changing the spec's meaning under everyone, with no
  version or migration. *Fix:* semantic versions, deprecation windows, bump tooling.
- **Build-vs-buy by hype.** Adopting a tool because it is trendy, or building a
  catalog UI because building is fun. *Fix:* score each component on differentiation,
  op-cost, time-to-value, and lock-in.

---

## 8. Assessment

**Knowledge checks**

1. What does the orchestration layer do, and why can no single plane satisfy a "new
   service with a database" request alone?
2. List three properties of a well-designed platform API and why each matters.
3. Explain "convention over configuration" with a concrete example from a service
   request.
4. Give one component you would **buy** and one you would **build**, with the
   reasoning from the matrix.

**Concept exercise**

> Describe the architecture of an Internal Developer Platform to an engineer **without
> naming Backstage or any product** — focus on the contract developers hand you, the
> glue that fulfills it, and why the interfaces are interchangeable.

**Architecture / trade-off exercise**

> Your org wants a portal "by next quarter." A director proposes buying a SaaS portal
> and pointing it at your existing ticket queue for provisioning. Using the five
> planes, the API-first principle, and the orchestration idea, explain what this would
> and would not give you — and what you would build instead with the same budget.

<details>
<summary>Discussion</summary>

- **Q1:** It sequences the five planes so one request produces coordinated action
  (scaffold, deploy, provision, observe, secure). No single plane owns all of those;
  the glue is where your platform's opinion and the real engineering live.
- **Q2:** Declarative (state desired end-state, not steps), versioned/stable (it has
  consumers), documented (schema + defaults + examples), abstracted at the right level
  (workloads, not raw YAML). Each protects consumers and keeps interfaces swappable.
- **Q3:** The developer supplies only service-specific facts (name, owner, needs a
  Postgres); non-root containers, SBOMs, dashboards, and limits are defaults supplied
  by the path — fewer decisions, right thing by default.
- **Q4:** Buy/adopt the portal and catalog UI (commodity, low differentiation); build
  the orchestration and golden paths (your opinion, your moat). Justify via
  differentiation and lock-in.
- **Trade-off:** A SaaS portal over a ticket queue gives you a nicer developer control
  *plane* surface but **no self-service** — the other four planes are still
  human-driven, so it is "a ticket queue with better fonts" (01.4). With the same
  budget, design the platform API and build the orchestration for *one* golden path
  (thin slice across all five planes), then put any portal in front of it.

</details>

---

## 9. Further reading

- CNCF — [Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
  and the [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)
- Humanitec — [IDP reference architecture and the Platform Orchestrator](https://humanitec.com/blog/what-is-an-internal-developer-platform)
- [Score](https://score.dev/) — an open workload specification (a platform-API shape)
- [PlatformEngineering.org](https://platformengineering.org/) — reference
  architectures and the community
- Martin Fowler — [Platform Engineering and the platform-as-a-product idea](https://martinfowler.com/articles/platform-prerequisites.html)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15 · Developer Experience and IDP](../README.md)
· _Next:_ [15.2 — Backstage Fundamentals →](../02-backstage-fundamentals/)
