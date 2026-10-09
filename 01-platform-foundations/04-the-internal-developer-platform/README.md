# Module 01.4 — The Internal Developer Platform

> An Internal Developer Platform (IDP) is the *product* a platform team builds: the
> self-service layer between developers and the underlying infrastructure. This
> module gives you the architecture literacy you'll use for the rest of the course —
> the **five planes** of an IDP, a reference architecture, the core capabilities,
> the build-vs-buy landscape, and the anti-patterns that sink IDPs.

**Estimated effort:** ~1.5 hours (theory + lab)
**You'll need:** [Modules 01.1–01.3](../).

## Learning objectives

By the end of this module you will be able to:

- Define an IDP and its scope, and distinguish it from "a portal."
- Describe the **five planes** of an IDP and what each is responsible for.
- Sketch an IDP **reference architecture** and name the capabilities it must offer.
- Reason about **build vs buy** across Backstage, Port, Cortex, Compass, and custom.
- Recognize IDP **anti-patterns** and explain why the **platform API** is the real
  product.

---

## 1. Concept

### What an IDP is (and isn't)

An **Internal Developer Platform (IDP)** is the set of self-service tools, services,
and automated workflows that let developers provision, deploy, and operate their
applications without needing to understand — or wait on — the underlying
infrastructure.

- It **is** a product with an interface developers use directly (a CLI, an API, a
  portal) backed by **real automation**.
- It **is not** merely a portal, a wiki, or a Backstage install. A pretty front end
  over a ticket queue is not an IDP — it's a ticket queue with better fonts.

> The CNCF defines an IDP as a *"bespoke system of components and tooling, built by
> a platform engineering team, to create golden paths and enable developer
> self-service."* The emphasis is on **self-service** and **golden paths**, not on
> any specific product.

### The five planes of an IDP

A durable mental model (from the platform engineering community and Humanitec's
reference architecture) splits an IDP into **five functional planes**. Planes, not
layers — each is a *concern*, and a given tool may touch several.

```text
┌──────────────────────────────────────────────────────────────────────┐
│ 1. DEVELOPER CONTROL PLANE                                             │
│    The interface developers use: portal, CLI, API, git-based workflow. │
│    "How a developer asks for something."                               │
├──────────────────────────────────────────────────────────────────────┤
│ 2. INTEGRATION & DELIVERY PLANE                                        │
│    CI/CD, GitOps, image/artifact management, config orchestration.     │
│    "How code and config get built and delivered."                      │
├──────────────────────────────────────────────────────────────────────┤
│ 3. RESOURCE PLANE                                                      │
│    The actual resources: clusters, compute, databases, queues, DNS —   │
│    provisioned via IaC / Crossplane. "Where things actually run."      │
├──────────────────────────────────────────────────────────────────────┤
│ 4. MONITORING PLANE                                                    │
│    Observability, logging, tracing, alerting, cost visibility.         │
│    "How you see what's happening and what it costs."                   │
├──────────────────────────────────────────────────────────────────────┤
│ 5. SECURITY PLANE                                                      │
│    Identity, access control, secrets, policy enforcement.              │
│    "How it stays safe and compliant."                                  │
└──────────────────────────────────────────────────────────────────────┘
```

Each plane maps to a later phase of this course:

| Plane | You'll build it in |
|-------|--------------------|
| Developer control plane | 15 · Developer Experience & IDP (Backstage, CLI) |
| Integration & delivery | 06 · CI/CD, 07 · Package Mgmt, 08 · GitOps |
| Resource plane | 03 · Kubernetes, 05 · IaC (Terraform, Crossplane) |
| Monitoring plane | 11 · Observability, 18 · FinOps |
| Security plane | 13 · Security & Policy, 14 · Networking |

Keep this table in mind: the whole course is, in effect, building out the five
planes one at a time.

### Reference architecture

How the planes fit together at runtime:

```text
                         Developer
                             │
                             ▼
            IDP Portal / CLI / API          ← Developer Control Plane
                             │
                             ▼
             Platform Orchestration Layer    ← ties the planes together
                             │
     ┌───────────────┬───────┴───────┬───────────────────┐
     ▼               ▼               ▼                   ▼
 GitOps Engine   IaC Engine      Secrets Manager    Observability
 (ArgoCD)        (Terraform/XP)  (Vault/ESO)        Platform
  config delivery  provisioning   secret injection   runtime telemetry
     │               │               │                   │
     └───────────────┴───────┬───────┴───────────────────┘
                             ▼
                     Kubernetes Clusters
                             │
                             ▼
                       Cloud Resources
```

The **orchestration layer** is the connective tissue: it takes a developer's
request ("I want a new service with a database in staging") and coordinates the
GitOps engine, IaC engine, secrets, and observability to fulfill it. Humanitec calls
this role a **Platform Orchestrator**; you can also assemble it from open-source
pieces (Crossplane + ArgoCD + glue). The pattern matters more than the product.

### Core IDP capabilities

Regardless of how it's built, a mature IDP offers these capabilities:

- **Self-service provisioning** — create services, environments, and resources on
  demand.
- **Environment management** — spin up/down dev, staging, preview, and prod
  environments consistently.
- **Application catalog** — a live inventory of what exists, who owns it, where it
  runs, and how it's doing.
- **Deployment automation** — safe, repeatable delivery (usually GitOps).
- **Secrets management** — inject secrets without developers handling raw
  credentials.
- **Observability** — metrics, logs, traces, and cost, wired in by default.
- **Access control** — the right people and services get the right permissions,
  least-privilege by default.

A useful self-assessment: *for each capability, is it self-service, ticket-driven,
or absent?* (That's the lab.)

### The platform API is the product

Portals come and go; the **platform API** endures. The most important design
decision is a **stable, versioned, documented API** (often expressed as a
declarative spec in Git — "here is the service I want") that every interface sits on
top of:

```text
Portal (Backstage)  ─┐
CLI (platform ...)   ─┼──►  Platform API  ──►  orchestration ──► the five planes
CI/CD automation     ─┘      (stable, versioned, declarative)
```

Why API-first wins:

- Interfaces (portal, CLI, pipelines) become thin clients you can swap or add.
- Automation can consume the platform the same way humans do.
- You can change the implementation behind the API without breaking developers.

> Design the contract (the API/spec) first; treat the portal as *one* client of it,
> not the product itself.

### Build vs buy: the developer-portal landscape

For the **developer control plane**, the common options:

| Option | What it is | Consider when… |
|--------|-----------|----------------|
| **Backstage** | Open-source framework (CNCF), highly extensible | You want control/extensibility and have engineering capacity to run it. *(This course uses it.)* |
| **Port** | SaaS developer portal, fast to stand up | You want results quickly without operating the portal yourself. |
| **Cortex** | SaaS, strong on service maturity/scorecards | Service catalog + standards tracking is your priority. |
| **Compass (Atlassian)** | SaaS, integrates with Atlassian stack | You're deep in the Atlassian ecosystem. |
| **Custom** | Build your own UI/CLI on your platform API | Your needs are unusual and the API-first core is solid. |

Apply Module 01.2's heuristic: the **portal is largely a commodity**; your
differentiation is the **golden paths and orchestration** behind it. Don't let
"which portal?" consume the energy that belongs on the paved roads. A CLI + good
docs is a perfectly legitimate control plane for a thin v1 (remember the TVP).

---

## 2. Why it matters for platform engineering

The five-planes model is the **map** you'll navigate for the rest of the course.
Without it, the later phases feel like a disconnected tour of tools; with it, each
tool has an obvious home and purpose. It also:

- gives you a **vocabulary** to discuss platform architecture with peers and
  leadership;
- provides a **gap-analysis framework** (which planes/capabilities are weak?);
- keeps you honest that an IDP is **more than a portal** — it's five coordinated
  concerns.

When you can look at any platform and immediately locate its five planes, its
orchestration, and its API, you're thinking like a platform architect.

---

## 3. Mental model

```text
An IDP = a stable Platform API + orchestration across FIVE PLANES,
         exposed through self-service interfaces, delivering golden paths.

Ask of any IDP:
  1. What's the developer control plane? (how do they ask?)
  2. Is there a real, versioned platform API — or just a UI?
  3. For each capability: self-service, ticket, or absent?
  4. Are all five planes present, or is one (usually security or monitoring)
     bolted on as an afterthought?
```

If the honest answer to "self-service or ticket?" is "ticket" for most
capabilities, you have a portal, not a platform — yet.

---

## 4. Minimal implementation

The thinnest honest IDP is **a declarative request + automation that fulfills it**.
Imagine a single file a developer commits:

```yaml
# platform-request.yaml — the "platform API" as a v0 declarative spec
service:
  name: payments
  owner: team-payments
  language: go
environments:
  - name: dev
    resources:
      - type: postgres
        size: small
```

…and a thin orchestration that reacts to it:

```text
commit platform-request.yaml
        │
        ▼
  automation reads the spec and:
   • scaffolds the repo from the Go golden-path template   (control + delivery)
   • opens a GitOps PR to deploy to dev                    (delivery plane)
   • provisions a small Postgres via IaC/Crossplane        (resource plane)
   • wires a default dashboard + secret injection          (monitoring + security)
```

Notice: **no portal yet**. The developer's interface is a YAML file in Git; the value
is the automation across the planes behind it. That is a legitimate (thin) IDP — and
it's exactly the shape of what you'll build across this course. Add a CLI, then a
portal, *when demand justifies them* (TVP).

---

## 5. Hands-on lab

Assess an organization's platform against the five planes and the core
capabilities. You'll produce an **IDP capability assessment** — a gap analysis that
shows, for each capability, whether it's self-service, ticket-driven, or absent, and
what the thinnest valuable next step would be.

➡️ **[Start the lab: IDP Capability Assessment](./lab/README.md)**

---

## 6. Production considerations

- **API-first, always.** Decide the declarative spec/API before the portal. It's the
  part you'll regret getting wrong, and the part that outlives every UI.
- **Don't bolt on security and monitoring.** The security and monitoring planes must
  be *in the golden path by default*, not added later. Retrofitting them is painful
  and leaves gaps (this course treats them as structural, not optional).
- **Orchestration is the hard part.** Standing up ArgoCD, Terraform, and a secrets
  manager is table stakes; making them work together behind one request is the real
  engineering — and your differentiation.
- **Catalog accuracy decays.** An application catalog is only useful if it's
  *current*. Automate ingestion and staleness detection, or it rots into fiction.
- **Buy the portal, build the paths.** Spend your scarce effort on golden paths and
  orchestration, not on reimplementing a catalog UI.
- **Escape hatches per plane.** Teams will occasionally need raw access to a plane
  (direct kubectl, direct Terraform). Provide sanctioned, auditable escape hatches
  rather than forcing everything through the happy path.

---

## 7. Common mistakes

- **The portal that wraps a ticket system.** The #1 anti-pattern: a shiny UI whose
  "provision" button files a ticket a human fulfills. That's not self-service. *Fix:*
  real automation behind the interface.
- **A platform that needs a platform-team ticket to use.** If adopting the platform
  itself requires the platform team to do manual setup, you've recreated the
  bottleneck. *Fix:* onboarding must be self-service too.
- **Mistaking a tool for the platform.** "We installed Backstage, so we have an
  IDP." Backstage is (part of) a control plane; an IDP is five planes plus
  orchestration and an API. *Fix:* the five-planes check.
- **Missing or afterthought planes.** Security or monitoring left for "later" →
  insecure or unobservable by default. *Fix:* bake them into the golden path.
- **UI-first instead of API-first.** Building the portal before the API, then being
  unable to automate or swap the UI. *Fix:* design the contract first.
- **Boiling the ocean.** Trying to build all five planes fully before shipping
  anything. *Fix:* a thin slice across the planes for one golden path (the minimal
  implementation above).

---

## 8. Assessment

**Knowledge checks**

1. Name the five planes of an IDP and one responsibility of each.
2. Why is a "portal with a provision button that files a ticket" *not* an IDP?
3. What does "the platform API is the product" mean, and why is API-first better
   than UI-first?
4. Give one IDP capability you'd buy and one you'd build, with reasoning.

**Concept exercise**

> Describe an Internal Developer Platform to an engineer **without naming any
> product** (no Backstage, ArgoCD, Terraform). Focus on what it does for developers
> and the concerns it coordinates.

**Architecture exercise**

> Sketch (in text or a diagram) a minimal IDP that lets a developer request "a new
> Go service with a small Postgres in dev" entirely self-service. Label which of the
> five planes each part touches, and identify where the platform API sits.

<details>
<summary>Discussion</summary>

- **Q1:** Developer control plane (the interface), integration & delivery (CI/CD,
  GitOps, artifacts), resource plane (clusters/compute/DBs via IaC), monitoring
  (observability + cost), security (identity, secrets, policy).
- **Q2:** Because the defining property is *self-service* — automation fulfills the
  request. A ticket keeps a human in the loop for routine work, which is the
  bottleneck the IDP exists to remove.
- **Q3:** It means the stable, versioned, declarative contract (often a spec in Git)
  is the enduring product; portals/CLIs are thin clients of it. API-first lets you
  add/swap interfaces and automate against the platform, and change the
  implementation without breaking developers.
- **Q4:** Buy the portal/catalog (commodity); build the golden-path orchestration
  (your org-specific opinion and glue).
- **Architecture:** A declarative spec in Git (the API, control plane) → orchestration
  → GitOps to deploy (delivery) + Crossplane/Terraform for Postgres (resource) +
  default dashboard (monitoring) + secret injection and least-privilege access
  (security). Interface can be a YAML file or a CLI in v1 — no portal required.

</details>

---

## 9. Further reading

- CNCF — [*Platforms White Paper*](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
  and the [IDP definition](https://glossary.cncf.io/internal-developer-platform/)
- Humanitec — [IDP reference architecture & the five planes](https://humanitec.com/blog/what-is-an-internal-developer-platform)
- [Backstage](https://backstage.io/) · [Port](https://www.port.io/) ·
  [Cortex](https://www.cortex.io/) · [Atlassian Compass](https://www.atlassian.com/software/compass)
- [PlatformEngineering.org](https://platformengineering.org/) — community reference
  architectures

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [01.3 — Developer Experience](../03-developer-experience/)
· _Next:_ [01.5 — Platform Team Topology →](../05-platform-team-topology/)
