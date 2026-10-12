# 21 · Capstone Projects

> This is where it all comes together. The four capstones are **portfolio-grade,
> integrative builds** that combine everything from the course into complete,
> documented, reproducible platforms. Projects 1–4 taught you the pieces on a local
> cluster; the capstones ask you to assemble them into systems another organization
> could actually adopt. Finishing one well is the single strongest signal that you can
> do this job.

**These are not lessons.** There is no new material to read here — the capstones draw
on the phases and projects you've already completed. Each is a brief: a goal, a
requirements checklist, a suggested architecture, and a definition of done. **How** you
build it is up to you.

## The four capstones

| # | Capstone | What you build | Builds on |
|---|----------|----------------|-----------|
| 1 | [Production Kubernetes Platform](./01-production-kubernetes-platform/) | A complete multi-team, production-grade Kubernetes platform from scratch. | Projects 1–3; Phases 2–14 |
| 2 | [Full IDP with Backstage](./02-full-idp-with-backstage/) | An IDP that onboards a new team from zero to production in under 30 minutes. | Project 4; Phase 12 |
| 3 | [Multi-Cluster GitOps Platform](./03-multi-cluster-gitops-platform/) | A multi-cluster, multi-region platform with promotion automation and DR. | Projects 2–3; Phases 7, 13, 15 |
| 4 | [Production Platform Reference Architecture](./04-production-platform-reference-architecture/) | All of the above, combined into one documented reference architecture. | Everything |

You don't have to do all four. **Capstone 4 is the ultimate goal** — it *is* the first
three, integrated and documented. If you're building a portfolio, pick the one that
best demonstrates the role you want, do it to the
[portfolio standard](./portfolio-standard.md), and document it thoroughly.

## How to approach a capstone

1. **Start from the brief, not the tools.** Read the capstone's goal and requirements.
   Write the README's problem statement *first* — if you can't state the problem, you're
   not ready to build.
2. **Reuse your project work.** The capstones are supersets of Projects 1–4. Lift your
   Terraform modules, GitOps config, observability stack, golden paths, and runbooks —
   don't start from a blank page.
3. **Build incrementally and keep it reproducible.** A capstone someone else can't
   deploy from scratch isn't a capstone. Script the bootstrap; test the teardown.
4. **Document as you go.** ADRs for every significant choice, runbooks for failure
   modes, an onboarding guide, known limitations. The documentation *is* half the
   deliverable.
5. **Hold yourself to the two standards below.** A capstone is "done" when it meets the
   [portfolio standard](./portfolio-standard.md) and answers every question in the
   [production readiness checklist](./production-readiness-checklist.md).

## The two standards

Every capstone is measured against these. Read them before you start, and again before
you call it done:

- **[Portfolio standard](./portfolio-standard.md)** — what makes a project a portfolio
  piece rather than "a cluster of YAML files."
- **[Production readiness checklist](./production-readiness-checklist.md)** — the
  availability, security, observability, cost, and operations questions a real platform
  must answer.

## A note on cost

The capstones are the one place in the course where a **real cloud deployment** makes
the strongest portfolio piece — a live GKE platform you can demo is more convincing
than a local `kind` cluster. That said, you can build and demonstrate most of each
capstone locally (kind + the open-source stack) and document the cloud deltas.

**If you do go to the cloud:** set a budget alert first
([cloud account setup](../00-orientation/cloud-account-setup.md)), use the smallest
viable node sizes and spot where possible (you learned the FinOps habits in
[Phase 14](../18-finops-and-cost-engineering/)), and **tear everything down** when
you're done — the cleanest teardown is deleting the whole project. A capstone that left
a cluster running for a month is a cautionary tale, not a portfolio piece.

---

Pick a capstone and open its brief. Most people start with
[**Capstone 1 — Production Kubernetes Platform →**](./01-production-kubernetes-platform/).

---

_Previous:_ [20 · Advanced Platform Topics](../20-advanced-platform-topics/)
· _Next:_ [22 · Interview Preparation](../22-interview-preparation/)
