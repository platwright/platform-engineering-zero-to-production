# Module 15.6 — Golden Paths

> A golden path is the recommended, supported, opinionated way to do a common thing —
> and it is the product your whole platform exists to deliver. [Module 01.3](../../01-platform-foundations/03-developer-experience/)
> defined it; Modules 15.4 and 15.5 built the pieces. This module assembles them into a
> *complete, end-to-end* golden path: everything it must include, the escape hatches
> that keep it honest, how you version it, and how you measure whether anyone uses it.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** Modules [15.4](../04-backstage-software-templates/) and
[15.5](../05-backstage-plugins/); the versioning ideas from
[Module 06.4](../../06-cicd-for-platform-teams/04-pipeline-templates-as-product/).

## Learning objectives

By the end of this module you will be able to:

- Define a golden path and list the end-to-end capabilities it must include.
- Design **escape hatches** as a documented, reviewed, visible process.
- Version a golden path and provide a **v1 → v2 migration** with tooling.
- Define and track golden-path **adoption metrics**.

---

## 1. Concept

### A golden path is end-to-end, or it is not golden

Module 01.3 defined a golden path as the paved road for a specific journey — "create a
new Go service." The crucial word is **end-to-end**. A template that scaffolds a repo
but leaves the developer to wire CI, deployment, observability, and docs by hand is not
a golden path; it is a nicer starting line for the same marathon. A golden path carries
a change from *idea* to *running, observable, documented production service* without
the developer leaving the paved road.

So the golden path is not any single tool from this phase — it is the **composition** of
them, orchestrated (Module 15.1) behind one request.

### What a golden path must include

A complete golden path for a service wires in, by default, every capability you built
across the course:

- **Repository scaffold** — a working skeleton from the Backstage template (Module
  15.4): code, structure, sane config.
- **CI/CD pipeline** — the platform's reusable workflow (Module 06.4), consumed, not
  re-authored: lint, test, build, scan.
- **Container build and push** — a secure multi-stage image to the registry (Phase 2).
- **IaC for cloud resources** — if the service needs a database or bucket, provisioned
  via Terraform/Crossplane (Phase 5), not a ticket.
- **GitOps deployment config** — an ArgoCD `Application` and manifests so the service
  deploys itself (Phase 8, Project 2).
- **Observability** — the OpenTelemetry SDK pre-configured and a default dashboard
  (Phase 11, Project 3) — wired in, not bolted on.
- **Security** — non-root containers, a signed image, and an SBOM by default (Phase
  13); least-privilege access.
- **Documentation** — a TechDocs skeleton so the service is documented from day one
  (Module 15.8).

```text
Developer requests "new service" in the portal
  │
  ▼  the golden path creates, in one flow:
  ├─ GitHub repo (skeleton: code, Dockerfile, chart, catalog-info.yaml)
  ├─ CI/CD workflow (consumes the platform template)
  ├─ config-repo entry (GitOps Application)
  ├─ namespace in the dev cluster (via the Namespace Operator — Project 1)
  ├─ monitoring dashboard (from a Grafana template)
  ├─ secret wiring (via External Secrets)
  └─ docs skeleton (TechDocs)
  │
  ▼
Developer starts coding in a pre-wired, production-ready service
```

Every item on that list is something a team used to do by hand (or skip). The golden
path makes the secure, observable, deployable choice the **default** — "make the right
thing the easy thing" (Module 01.3), by construction.

### Escape hatches: documented, reviewed, visible

From Module 01.3 and 06.4: golden paths are the *easiest* route, not a mandatory cage.
Real teams have legitimate exceptions — a service that needs a database the path does
not support yet, or a non-standard base image. A golden path without escape hatches
gets **forked and routed around**, and you lose all visibility. So make deviation a
**process, not a rebellion**:

- **Documented.** A written way to request a deviation, with the trade-offs stated.
- **Reviewed.** Higher-stakes deviations get a lightweight platform sign-off (a label +
  approval), not a silent fork.
- **Visible and counted.** Every escape hatch is logged and shows up in a report. A
  frequently used hatch is a **bug report about your defaults** — change the path.

The rule holds: *guardrails are for safety (mandatory); paths are preferences (win by
being better).* Never use a safety mechanism to enforce a preference.

### Versioning and migration

A golden path has consumers, so it is a product with versions — the exact discipline
from Module 06.4, now applied to the whole path:

- **Semantic versions.** `v1`, `v1.1`, `v2`. Non-breaking improvements flow to
  consumers; breaking changes mean a new major.
- **Deprecate, do not delete.** When `v2` lands, `v1` keeps working with a warning and
  a sunset date.
- **Migration tooling.** Do not just publish a guide — ship a **codemod or bot** that
  opens the PR to move a service from `v1` to `v2`. Migration you make easy actually
  happens; migration you document gets ignored.

> You cannot update a golden path in place for 200 services by editing one file —
> because the path is distributed across each service's repo. Versioning plus migration
> tooling is how you evolve it safely.

### Adoption metrics: the scoreboard

A beautiful golden path nobody uses is a failed product (Module 01.1). Measure, from
day one:

- **Coverage** — what percent of production services are *on* a golden path at all?
- **Version adoption** — what percent are on the *current* version vs. a deprecated
  one? Slow migration means your migration path is too painful.
- **Escape-hatch rate** — how often is each hatch used? A spike says the default is
  wrong.
- **Time-to-adopt** — how long from `v2` release to the fleet moving? This measures
  your migration tooling.

Pair these with the north-star from Module 01.3 — **time-to-first-production-deployment**
for a new service on the path. If the golden path works, that number is hours, not
weeks.

---

## 2. Why it matters for platform engineering

This module is the keystone of the phase. The catalog, templates, and plugins are
components; the **golden path is the product** they combine into — the single thing a
platform team can point to and say "this is how you ship here, and it is genuinely the
easiest way." Everything in Projects 1–3 was building the capabilities; the golden path
is where they become *self-service* for real.

It is also where platform engineering is most clearly **product management, not just
engineering**. Owning a golden path means owning its versioning, migrations, escape
hatches, support, and adoption — the same work a product manager does for external
customers, aimed at your own developers. Teams that do this well get security and
reliability *by default* across the whole fleet, from one place.

---

## 3. Mental model

```text
     GOLDEN PATH = the end-to-end paved road, owned as a product
     ──────────────────────────────────────────────────────────

   MUST INCLUDE (by default, not opt-in):
     scaffold · CI/CD · image · IaC · GitOps · observability · security · docs

   KEEP IT HONEST:
     escape hatches = documented + reviewed + visible/counted (not forks)
     guardrails (safety) mandatory · paths (preference) win by being better

   OWN IT AS A PRODUCT:
     version (v1→v2) · deprecate not delete · SHIP migration tooling
     measure: coverage · version adoption · hatch rate · time-to-first-deploy

   One line: make the secure, observable, deployable choice the DEFAULT —
             end to end — then version it and prove adoption.
```

One sentence: **a golden path is the complete, opinionated, self-service route to
production, owned and versioned like a product and measured by adoption.**

---

## 4. Minimal implementation

You already built the pieces; the smallest "golden path" is composing them and writing
down what "done" means. Take the Module 15.4 template and ensure its skeleton wires in
*every* required capability by default, then publish a one-page definition:

```text
Golden path: "standard Go service"  (v1)
  scaffold       → Backstage template `go-microservice` (Module 15.4)
  CI/CD          → skeleton CI uses platform workflow `app-ci@v2` (Module 06.4)
  image          → multi-stage non-root Dockerfile, signed in CI (Phase 2/13)
  GitOps         → skeleton includes an ArgoCD Application (Phase 8)
  observability  → OTel SDK pre-wired + default dashboard (Phase 11)
  security       → non-root, SBOM, least-privilege RBAC (Phase 13)
  docs           → TechDocs skeleton (Module 15.8)
  escape hatch   → `advanced` params (base image), default-off, logged
  owner + support → team-platform, #platform-support, SLO published
  adoption metric → % of prod Go services created from this template @ current version
```

That one page *is* the golden-path contract: what it includes, who owns it, how to
deviate, and how you will know it is working. The lab turns it into a reusable
checklist you can apply to any golden path.

---

## 5. Hands-on lab

You will define a complete golden path and assess it against a **readiness checklist**:
confirm every required capability is wired in by default, design its escape hatch,
write its versioning/migration plan, and choose its adoption metrics. The deliverable is
a filled-in [golden-path checklist](./lab/golden-path-checklist.md) you can reuse for
every path your platform offers.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **"By default" is the whole game.** If security, observability, or GitOps are opt-in
  steps rather than baked into the skeleton, teams will skip them. Make them automatic.
- **Ship migration tooling, not just guides.** A bot that opens the `v1 → v2` PR is the
  difference between a migration that happens and one that stalls for a year.
- **Treat a stale golden path as an incident.** An out-of-date path leads people
  confidently into a ditch (Module 01.3). Own it like production software.
- **Make escape-hatch usage a feedback loop.** Review hatch metrics regularly; a
  popular hatch is a backlog item to fold into the default path.
- **Keep the number of paths small.** A few well-maintained golden paths beat a dozen
  half-maintained ones. Parameterize before you proliferate (Module 15.4).
- **Publish the contract.** Owner, support channel, SLO, versioning policy, and
  deprecation calendar — consumers need to know what they can depend on (Module 01.3).

---

## 7. Common mistakes

- **A "golden path" that is only a scaffold.** It creates a repo but not CI,
  deployment, observability, or docs. *Fix:* end-to-end or it is not golden.
- **Security and observability as optional steps.** Left to the developer, they get
  skipped. *Fix:* bake them into the skeleton as defaults.
- **No escape hatch, so teams fork.** Forbidding deviation hides it. *Fix:* a
  documented, reviewed, counted hatch.
- **Updating in place with no versioning.** Changing the path under 200 services at
  once. *Fix:* semantic versions, deprecation, and migration tooling.
- **Publishing a migration guide but no tooling.** Adoption of `v2` stalls. *Fix:* ship
  a bot/codemod that opens the bump PR.
- **No adoption metric.** You cannot tell if the product succeeded. *Fix:* track
  coverage, version adoption, hatch rate, and time-to-first-deploy.

---

## 8. Assessment

**Knowledge checks**

1. Why must a golden path be end-to-end, and name five capabilities it must include by
   default.
2. What three properties make an escape hatch healthy rather than a silent fork?
3. Why can you not update a distributed golden path "in place," and what do you do
   instead?
4. Name three golden-path adoption metrics and what a spike in escape-hatch usage tells
   you.

**Concept exercise**

> Explain what a golden path is to a skeptical senior engineer who says "I don't need
> training wheels" — **without using the words "golden path" or "Backstage."** Frame it
> around defaults, speed, and the escape hatch.

**Architecture / trade-off exercise**

> Your `v1` Go golden path is at 70% coverage, but a third of those services are still
> on `v1` after you shipped `v2` six months ago, and two teams forked the template to
> use a database you do not support. Diagnose each issue using versioning, migration
> tooling, escape hatches, and adoption metrics — and give the fix for each.

<details>
<summary>Discussion</summary>

- **Q1:** Because value is only delivered when a change reaches running, observable,
  documented production — a scaffold alone leaves the hard parts undone. Must include
  (any five): scaffold, CI/CD, image build, IaC, GitOps deploy, observability,
  security, docs.
- **Q2:** Documented (a written request process), reviewed (sign-off for higher-stakes
  deviations), and visible/counted (logged and reported so it is a feedback signal).
- **Q3:** The path is distributed across each service's repo, so there is no single file
  to edit. Instead you version it (v1 → v2), deprecate the old version, and ship
  migration tooling to move services.
- **Q4:** Coverage, version adoption, escape-hatch rate, time-to-adopt/time-to-first-
  deploy. A hatch spike means your default is wrong and the path should change.
- **Trade-off:** Stuck on `v1` → migration is too painful; ship a bump bot and a
  generous sunset window. Forked for an unsupported DB → that is unmet demand; add a
  supported, default-off database option (or pave that road) and fold the fork back in.
  No visibility into forks → make the hatch a counted process. Track coverage and
  version adoption as the scoreboard.

</details>

---

## 9. Further reading

- Thoughtworks — [Paved roads and golden paths](https://www.thoughtworks.com/insights/blog/engineering-effectiveness/platform-engineering-golden-paths)
- Spotify Engineering — [Golden paths at Spotify](https://engineering.atspotify.com/2020/08/how-we-use-golden-paths-to-solve-fragmentation-in-our-software-ecosystem/)
- CNCF — [Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/) (golden paths and self-service)
- [PlatformEngineering.org](https://platformengineering.org/) — golden paths in practice
- Backstage — [Software Templates](https://backstage.io/docs/features/software-templates/) (the scaffold end of the path)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.5 — Backstage Plugins](../05-backstage-plugins/)
· _Next:_ [15.7 — Platform CLI Tools →](../07-platform-cli-tools/)
