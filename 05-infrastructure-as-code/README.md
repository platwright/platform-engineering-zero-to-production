# 05 · Infrastructure as Code

> Up to now your platform has run on clusters and containers *someone clicked into
> existence*. That doesn't scale, isn't reproducible, and can't be reviewed. This
> phase replaces the clicking with **code**: infrastructure you can version, review,
> test, and apply the same way every time. It's the mechanism that turns "it works
> on my cluster" into "it works in every environment, on demand."

**Phase 4 · 7 modules · ~14–20 hours**

## Why this phase?

A platform is only as reliable as the way its infrastructure is created. If your
staging and production environments were built by hand, they have silently drifted
apart, nobody can recreate them after a disaster, and every change is a risk because
there is no plan to review and no record of what happened.

**Infrastructure as Code (IaC)** fixes this at the root. You describe the desired
state of your infrastructure — clusters, networks, buckets, databases, IAM — in
files that live in Git. A tool reconciles reality to match. The result is
infrastructure that is **reproducible, reviewable, testable, and self-documenting**.

This phase is also where the platform team earns much of its leverage. The reusable
Terraform modules and Crossplane abstractions you build here become the paved road
that every other team consumes: a product team asks for a database with ten lines of
YAML instead of a two-week ticket queue. That is platform engineering in action.

We teach the **problem before the tool** throughout:

- **State and idempotency** — what they are and why any IaC tool needs them —
  *before* a single `terraform apply`.
- **Drift** — why reality diverges from code and how to detect it.
- **Modules and composition** — the DRY, versioned building blocks of a real IaC
  codebase, not copy-pasted HCL.
- **Testing and policy** — security scanning, policy-as-code, and Go integration
  tests, because unreviewed infrastructure is a liability.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [IaC Principles](./01-iac-principles/) | Declarative vs imperative, idempotency, state, drift, the IaC lifecycle, and when *not* to use IaC. | A hand-written idempotent reconciler + drift report. |
| 2 | [Terraform Fundamentals](./02-terraform-fundamentals/) | Providers, resources, variables, outputs, dependencies, and the core `init/plan/apply/destroy` loop. | A local multi-resource Terraform project. |
| 3 | [Terraform State Management](./03-terraform-state-management/) | Local vs remote state, locking, inspection, `state mv`/`rm`, migrations, and workspaces. | A backend migration + state surgery exercise. |
| 4 | [Terraform Modules](./04-terraform-modules/) | Module structure, composition, interface design, versioning, and an internal module library. | A reusable module consumed by two environments. |
| 5 | [Terraform Testing and Quality](./05-terraform-testing-and-quality/) | `fmt`/`validate`, tfsec/Checkov, OPA/Conftest, Terratest, and PR-driven plan/apply. | A tested, scanned, policy-checked module. |
| 6 | [Crossplane](./06-crossplane/) | Managed resources, XRDs, compositions, and self-service infrastructure via `kubectl`. | A self-service database API on a local cluster. |
| 7 | [IaC Patterns for Platform Teams](./07-iac-patterns-for-platform-teams/) | DRY, environment promotion, blast radius, governance, drift pipelines, and bootstrapping. | A mono-repo structure + drift-detection plan. |

Work them in order — each builds on the last. Together they take you from "what is
IaC and why does it need state?" to "here's a governed, tested, multi-environment
IaC codebase a platform team can run."

## Learning objectives

By the end of this phase you will be able to:

- Explain IaC from first principles — declarative desired state, idempotency,
  state, and drift — independent of any specific tool.
- Write, plan, and apply Terraform (or OpenTofu) to provision infrastructure, and
  reason about its dependency graph.
- Manage Terraform state safely: remote backends, locking, isolation, and state
  surgery without data loss.
- Design reusable, versioned modules with clean interfaces and compose them across
  environments.
- Enforce quality with formatting, static security scanning, policy-as-code, and
  automated tests in CI.
- Use Crossplane to offer self-service infrastructure as Kubernetes APIs, and know
  when it beats Terraform (and when it doesn't).
- Apply platform-team IaC patterns: blast-radius isolation, environment promotion,
  governance, and automated drift detection.

## Prerequisites

- [Phase 1 · Platform Foundations](../01-platform-foundations/) for the product and
  developer-experience lenses — IaC is a means, adoption is the goal.
- [Phase 2 · Containerization](../02-containerization/) and
  [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — the labs
  provision and extend Kubernetes.
- Everything in [`00-orientation/environment-setup.md`](../00-orientation/environment-setup.md):
  Docker, `kubectl`, and `kind`. You'll additionally install **Terraform** (or
  **OpenTofu**), and — for two modules — **Go** and **Crossplane** (on a local
  `kind` cluster).

## A note on cost

**These labs are designed to cost nothing.** We provision real infrastructure using
Terraform's `local`, `null`, `random`, and `kind`/`docker` providers, a local
backend, and `terraform plan` against cloud code without applying it. Where the
outline references **GKE/GCP**, the *lesson* shows the real, production-grade GCP
code so you learn the genuine article, but the *lab* runs locally and free. Any step
that could incur cloud spend is clearly marked with a **cost note** and always
includes a `terraform destroy` cleanup. Never skip cleanup.

---

Start with [**01 · IaC Principles →**](./01-iac-principles/)
