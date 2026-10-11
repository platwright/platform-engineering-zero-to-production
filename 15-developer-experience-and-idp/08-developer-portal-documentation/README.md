# Module 15.8 — Developer Portal Documentation

> A golden path makes the right thing easy; **documentation makes it well-lit.** The
> paved road is only paved if a developer can read where it goes, how to run the
> service, what to do when it pages them, and *why* it was built this way. This module
> covers **TechDocs** and **docs-as-code** (MkDocs docs that live with the code and
> render in the portal), a documentation structure for services, **ADRs**, API docs,
> **runbook standards**, and the rule that the platform itself must be documented best
> of all.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 15.2](../02-backstage-fundamentals/) (TechDocs is a core
plugin) and [15.3](../03-backstage-software-catalog/) (the `techdocs-ref` annotation).
Python + `pip` for a local MkDocs preview (optional).

## Learning objectives

By the end of this module you will be able to:

- Explain **docs-as-code** and how **TechDocs** renders MkDocs docs in the portal.
- Lay out a standard documentation set for a service (overview, architecture,
  runbooks, API).
- Write an **Architecture Decision Record (ADR)** and say why decisions need records.
- Define a **runbook standard** and connect it to alerting.
- Argue why the platform's own docs are a first-class deliverable.

---

## 1. Concept

### Docs-as-code: documentation lives with the code

The failure mode of documentation is a separate wiki that drifts from reality: the code
changes, the wiki does not, and within months the docs are confidently wrong — worse
than none. **Docs-as-code** fixes this the same way GitOps fixed config: put the
documentation **in the repository, next to the code**, written in Markdown, reviewed in
the same pull request as the change it describes, and versioned with it. When docs are a
PR-reviewable artifact, they stay honest.

### TechDocs: docs-as-code, rendered in the portal

**TechDocs** is Backstage's documentation plugin (Module 15.2). It takes
[MkDocs](https://www.mkdocs.org/)-based Markdown from a service's repo and renders it as
a browsable site **on that service's catalog page**. The developer reading about
`checkout-service` in the portal sees its docs right there, generated from the repo —
no separate wiki, no drift.

The wiring is a single annotation you already met in Module 15.3:

```yaml
# catalog-info.yaml
metadata:
  annotations:
    backstage.io/techdocs-ref: dir:.   # docs live in this repo
```

Plus two files in the repo: an `mkdocs.yml` and a `docs/` directory.

```text
   service repo                          Backstage
   ┌───────────────────────┐             ┌──────────────────────────┐
   │ mkdocs.yml            │  build +    │ checkout-service page     │
   │ docs/                 │  publish    │   └─ Docs tab (rendered   │
   │   index.md            │ ─────────►  │       from docs/ )        │
   │   architecture.md     │             │                          │
   │   runbooks/…          │             └──────────────────────────┘
   └───────────────────────┘
        docs-as-code                       same docs, in the portal
```

### A standard documentation structure

Convention over configuration applies to docs too (Module 15.1): a predictable
structure means developers always know where to look, and the golden-path skeleton can
ship it by default. A solid baseline for a service:

- **Overview / `index.md`** — what the service does, who owns it, how to run it
  locally. The "I just found this service, now what?" page.
- **Architecture** — how it works, its dependencies, and a diagram. The context a new
  maintainer needs.
- **Runbooks** — operational procedures: what to do when a specific alert fires.
- **API** — the interface contract (often the OpenAPI spec surfaced as an API entity,
  Module 15.3).
- **ADRs** — the record of *why* the important decisions were made.

### Architecture Decision Records (ADRs)

Code shows *what* the system does; it rarely shows *why* it is that way. Six months
later, nobody remembers why you chose Postgres over DynamoDB, and someone "fixes" it by
switching — re-learning the original reasons the hard way. An **ADR** is a short,
immutable record of one significant decision: its context, the options, the choice, and
the consequences.

```text
ADR 0007 — Use PostgreSQL for the orders datastore
  Status:        Accepted
  Context:       We need strong consistency and relational queries for orders.
  Decision:      Use managed PostgreSQL (Cloud SQL).
  Consequences:  Operable and familiar; must manage connection limits and backups.
```

ADRs are **append-only**: you do not edit a past decision, you supersede it with a new
ADR. The log becomes the architecture's memory. This course uses ADRs for its own
project decisions — see the shared
[ADR template](../../shared/templates/adr-template.md).

### API documentation

An interface nobody can read is a support ticket generator. Catalogue each service's
API from its **OpenAPI** spec as an API entity (Module 15.3) so consumers browse the
contract in the portal and self-serve instead of asking the owning team — a direct cut
to *waiting friction* (Module 01.3). Keep the spec in the repo and treat it as docs-as-
code too.

### Runbook standards: every alert links to a runbook

Observability (Phase 11) tells you *something is wrong*; a **runbook** tells you *what
to do about it*. The standard that makes this real is simple and strict:

> **Every alert must link to a runbook.** No runbook, no alert.

A good runbook is written for a stressed on-call engineer at 3am: the symptom, how to
confirm it, the likely causes, the step-by-step mitigation, and how to escalate. The
alert's annotation carries the link (`runbook_url`), so the pager notification is one
click from the fix. Runbooks live in `docs/runbooks/` as docs-as-code, rendered in
TechDocs, so they are versioned and discoverable — not a stale Google Doc.

### The platform must be the best-documented thing you own

"Knowledge and support" are in the definition of a platform (Module 01.1). A platform is
a product with customers, and an undocumented product does not get adopted. So the
platform's *own* docs — how to use each golden path, the platform API reference (Module
15.1), the support channel and SLOs (the platform contract from Module 01.3) — must be
exemplary. If your developers cannot find how to create a service without asking you,
you have recreated the ticket queue in documentation form. Dogfood TechDocs for the
platform itself.

---

## 2. Why it matters for platform engineering

Documentation is the difference between a golden path that is *discoverable* and one
that is tribal knowledge. You can build the best template, catalog, and CLI in the
world, but if a developer cannot find how to use them — or cannot tell, at 3am, what to
do when a service pages them — the platform's value is locked away. Docs-as-code plus
TechDocs is how the paved road gets signposts and streetlights.

It also closes the loop on the whole phase. The catalog (15.3) says *what exists*;
plugins (15.5) say *how it is doing*; TechDocs says *how it works, how to run it, and
why*. Together they make the portal a place developers can actually self-serve — which
is the entire point of the developer control plane. And runbooks tie the control plane
back to the monitoring plane: an alert from Project 3 becomes an actionable, documented
response.

---

## 3. Mental model

```text
     DOCS-AS-CODE + TECHDOCS = the paved road, well-lit
     ──────────────────────────────────────────────────

   docs live in the repo (Markdown) → reviewed in the SAME PR as the code
        │  mkdocs.yml + docs/        → stays honest, versioned with the code
        ▼
   TechDocs renders them on the service's catalog page (one annotation)

   Standard set:  overview · architecture · runbooks · API · ADRs
   ADR     = WHY a decision was made (append-only memory)
   Runbook = WHAT to do when an alert fires (every alert links to one)
   Meta    = the PLATFORM itself must be the best-documented product you own

   One line: put the docs with the code, render them in the portal, and make
             every alert one click from its runbook.
```

One sentence: **documentation is docs-as-code rendered in the portal — overview,
architecture, runbooks, API, and ADRs that live with the code and keep the golden path
discoverable.**

---

## 4. Minimal implementation

The smallest TechDocs setup is two files plus one annotation. An `mkdocs.yml` and a
`docs/index.md` in the service repo:

```yaml
# mkdocs.yml
site_name: checkout-service
nav:
  - Home: index.md
  - Architecture: architecture.md
plugins:
  - techdocs-core
```

```markdown
<!-- docs/index.md -->
# checkout-service

Handles payment and order checkout. Owned by team-payments.

## Run locally

    go run .
```

```yaml
# catalog-info.yaml — point TechDocs at the repo's docs
metadata:
  annotations:
    backstage.io/techdocs-ref: dir:.
```

Preview locally with `mkdocs serve`, and TechDocs renders the same `docs/` on the
service's portal page. From here you add `architecture.md`, a `runbooks/` folder, and an
`adr/` folder — the lab builds the full starter, including an ADR and a runbook.

---

## 5. Hands-on lab

You will create a docs-as-code starter for a service: an [`mkdocs.yml`](./lab/mkdocs.yml)
and a [`docs/`](./lab/docs/) tree with an overview, an architecture page, an
[ADR](./lab/docs/adr/0001-record-architecture-decisions.md), and a
[runbook](./lab/docs/runbooks/service-unavailable.md) that an alert would link to. You
will preview it with MkDocs locally and wire it to a catalog entity with the
`techdocs-ref` annotation.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Review docs in the code PR.** Treat a change with no doc update as incomplete. The
  only docs that stay accurate are the ones reviewed alongside the code.
- **Ship docs in the golden path.** The skeleton (Module 15.4) should include
  `mkdocs.yml`, a `docs/` tree, and the `techdocs-ref` annotation, so every service is
  documented from creation — convention, not an afterthought.
- **Enforce "every alert has a runbook."** Make `runbook_url` a required alert
  annotation and fail CI on alerts that lack it. An alert with no runbook is a 3am
  guessing game.
- **Build TechDocs in CI, not on demand.** For scale and speed, generate docs in a
  pipeline and publish to object storage; Backstage serves the built site rather than
  building per view.
- **Keep ADRs append-only.** Never rewrite history — supersede. The value is the record
  of *why*, including decisions you later reversed.
- **Document the platform best of all.** Dogfood TechDocs for the platform's own golden
  paths, API, and contract. Measure doc coverage like any other quality metric.

---

## 7. Common mistakes

- **A separate wiki.** Docs far from the code drift into confident fiction. *Fix:*
  docs-as-code in the repo, reviewed with the change.
- **Docs that are not part of "done."** Shipping code with no doc update. *Fix:* require
  doc changes in the PR; treat missing docs as a bug.
- **Alerts with no runbook.** The pager fires and on-call guesses. *Fix:* require
  `runbook_url`; no runbook, no alert.
- **No ADRs.** The *why* evaporates and decisions get silently reversed. *Fix:*
  lightweight, append-only ADRs for significant choices.
- **Editing past ADRs.** Rewriting a decision erases the memory. *Fix:* supersede with a
  new ADR; keep the old one.
- **An undocumented platform.** The platform team answers the same questions in Slack
  forever. *Fix:* exemplary, dogfooded platform docs — knowledge and support are part of
  the product.

---

## 8. Assessment

**Knowledge checks**

1. What problem does docs-as-code solve that a wiki does not, and how does TechDocs fit
   in?
2. What single annotation wires a repo's docs into its catalog page?
3. What is an ADR, what does it capture, and why is it append-only?
4. State the runbook standard and explain why it matters at 3am.
5. Why must the platform itself be the best-documented product you own?

**Concept exercise**

> Explain docs-as-code and runbooks to a team **without naming TechDocs, Backstage, or
> MkDocs.** Focus on where the docs live, when they are written, and what an on-call
> engineer needs.

**Architecture / trade-off exercise**

> Your org has a comprehensive wiki, but incidents still run long because on-call can't
> find current runbooks, and new hires can't tell why key decisions were made. Design
> the documentation strategy you would put in the golden path to fix both, and explain
> how it stays accurate over time.

<details>
<summary>Discussion</summary>

- **Q1:** Docs-as-code keeps documentation in the repo, reviewed in the same PR as the
  code, so it cannot drift the way a separate wiki does. TechDocs renders that
  repo-based Markdown on the service's portal page.
- **Q2:** `backstage.io/techdocs-ref` (e.g. `dir:.`) on the entity's `catalog-info.yaml`.
- **Q3:** An Architecture Decision Record captures one significant decision's context,
  options, choice, and consequences. It is append-only because the value is the
  historical record of *why* — you supersede rather than rewrite.
- **Q4:** Every alert must link to a runbook (no runbook, no alert). At 3am a stressed
  on-call engineer needs the symptom, confirmation, likely causes, mitigation steps, and
  escalation — one click from the page, not a wiki search.
- **Q5:** A platform is a product; "knowledge and support" are part of its definition.
  Undocumented, it does not get adopted and the platform team becomes the ticket queue
  it set out to remove.
- **Trade-off:** Move docs into each repo as docs-as-code rendered in the portal
  (runbooks in `docs/runbooks/`, linked from every alert's `runbook_url`; ADRs in
  `docs/adr/`), ship that structure in the golden-path skeleton so every service has it
  by default, and require doc updates in code review so it stays accurate. The wiki
  becomes, at most, cross-service narrative — not the source of operational truth.

</details>

---

## 9. Further reading

- Backstage — [TechDocs](https://backstage.io/docs/features/techdocs/)
- [MkDocs](https://www.mkdocs.org/) and [Material for MkDocs](https://squidfunk.github.io/mkdocs-material/)
- Michael Nygard — [Documenting architecture decisions (ADRs)](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
  and [adr.github.io](https://adr.github.io/)
- Google SRE Book — [On-call and writing runbooks/playbooks](https://sre.google/sre-book/being-on-call/)
- [Write the Docs](https://www.writethedocs.org/guide/) — docs-as-code practices
- The shared [ADR template](../../shared/templates/adr-template.md) used in this course

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.7 — Platform CLI Tools](../07-platform-cli-tools/)
· _Next:_ [Project 4 — Internal Developer Platform →](../../16-platform-project-04/)
