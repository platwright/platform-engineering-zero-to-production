# 06 · CI/CD for Platform Teams

> Up to now you have built container images, Kubernetes manifests, and Terraform
> modules — mostly by running commands on your own machine. That doesn't scale and
> it isn't safe. This phase turns those manual steps into **pipelines**: automated,
> reviewable, least-privilege workflows that build, scan, sign, and promote the
> platform's artifacts. Crucially, you'll learn why a platform team's CI/CD is a
> *different discipline* from application CI/CD — and why the pipeline itself is a
> product your developers consume.

**Phase 5 · 6 modules · ~10–14 hours**

## Why this phase?

Most engineers meet CI/CD as an application concern: run the tests, build the app,
deploy it. Platform CI/CD is a different animal. The thing being changed is the
*substrate every other team runs on* — clusters, networks, IAM, shared Helm charts,
base images, the pipeline templates themselves. A bad application deploy breaks one
service; a bad platform change can break every service at once. That raises the
stakes on review, blast radius, and the question *"who is allowed to approve this?"*

There is a second, quieter shift. In a mature platform, developers do **not** write
their own pipelines from scratch — they *consume* a pipeline the platform team
builds, versions, and supports. The pipeline is a golden path, exactly like the
`new-service.sh` of Module 01: encode the paved road once, let every team use it on
demand. That reframes CI/CD from "a YAML file in my repo" to "an internal product
with customers, versions, and adoption metrics."

This phase teaches the problem before the tool, throughout:

- **Why platform pipelines differ** — infrastructure, configuration, and validation
  pipelines, and a failure philosophy that fails fast and *loud*, never silently.
- **GitHub Actions from first principles** — triggers, jobs, contexts, environments,
  and why **keyless OIDC** beats long-lived cloud secrets every time.
- **Reuse** — composite actions and reusable workflows so you write a thing once and
  pin it by SHA everywhere.
- **Pipelines as a product** — versioning, migration, enforcement, escape hatches,
  and measuring adoption of the golden-path pipeline.
- **The two flagship pipelines** — a container `build → scan → sign → push` pipeline
  (Project 1) and a Terraform `plan-on-PR → apply-on-merge` pipeline (Project 2).

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [CI/CD Fundamentals for Platform Teams](./01-cicd-fundamentals-for-platform/) | Why platform CI/CD differs from app CI/CD; infrastructure vs configuration vs validation pipelines; fail-fast/fail-loud philosophy; review requirements. | A pipeline taxonomy + a fail-loud policy, validated locally. |
| 2 | [GitHub Actions Deep Dive](./02-github-actions-deep-dive/) | Workflow anatomy, events, contexts, environments and protection rules, concurrency, and keyless OIDC to the cloud. | A validated workflow with keyless OIDC auth (no secrets). |
| 3 | [Reusable Workflows and Composite Actions](./03-reusable-workflows-and-actions/) | Composite actions vs reusable workflows, inputs/outputs/secrets, SHA pinning, and a central action library. | A composite action + a reusable workflow, pinned by SHA. |
| 4 | [Pipeline Templates as a Platform Product](./04-pipeline-templates-as-product/) | Owning the templates, versioning and migration, enforcement, escape hatches, and adoption metrics. | A versioned `app-ci` template consumed by a caller repo. |
| 5 | [Container Build Pipelines](./05-container-build-pipelines/) | The `lint → test → build → scan → sign → push` arc, caching, multi-arch, Trivy gates, SBOMs, Cosign, digest promotion. | A full build→scan→sign→push workflow (Project 1). |
| 6 | [IaC Pipelines](./06-iac-pipelines/) | Terraform plan-on-PR, apply-on-merge, drift detection, per-environment gates, Atlantis, and least-privilege OIDC. | A Terraform plan/apply/drift pipeline (Project 2). |

Work them in order — each builds on the last. Together they take you from "what is a
platform pipeline?" to two production-shaped pipelines you will reuse in the course
projects.

## Learning objectives

By the end of this phase you will be able to:

- Explain how platform CI/CD differs from application CI/CD, and classify a pipeline
  as infrastructure, configuration, or validation.
- Author GitHub Actions workflows from first principles, using events, contexts,
  environments, concurrency, and keyless OIDC instead of long-lived secrets.
- Factor shared logic into composite actions and reusable workflows, pinned by SHA,
  and reason about when to build versus adopt an action.
- Treat a pipeline template as a product: version it, provide a migration path and
  escape hatches, enforce it for production, and measure its adoption.
- Build a container pipeline that lints, tests, builds, scans, generates an SBOM,
  signs keylessly, and promotes an immutable image by digest.
- Build a Terraform pipeline that plans on pull requests, applies on merge behind
  environment gates, and detects drift on a schedule.

## Prerequisites

- [Phase 2 · Containerization](../02-containerization/) — you build and sign the
  images those modules defined.
- [Phase 4 · Infrastructure as Code](../05-infrastructure-as-code/) — the Terraform
  the IaC pipeline plans and applies.
- A GitHub account (free tier is enough) and Git configured, per
  [`00-orientation/environment-setup.md`](../00-orientation/environment-setup.md).
- The labs are designed to be **free and mostly local**: you validate workflows with
  [`actionlint`](https://github.com/rhysd/actionlint) and optionally run them with
  [`act`](https://github.com/nektos/act), and run Trivy, Cosign, and `terraform plan`
  locally. Steps that need GitHub-hosted runners or a cloud account are clearly
  marked, with the core exercise always doable by writing and validating the workflow.

## A note on the labs

This phase is where the course's two platform projects get their engine. The
container pipeline you build in Module 06.5 is the `build → scan → sign → push` path
for **Project 1**; the Terraform pipeline in Module 06.6 is the `plan → review →
apply` path that, with GitOps in Phase 6, becomes **Project 2's** promotion-by-PR
into a config repository. Keep the workflow files you write — they are the first
real version of your platform's golden-path pipelines, and later phases refine them
rather than replace them.

---

Start with [**06.1 · CI/CD Fundamentals for Platform Teams →**](./01-cicd-fundamentals-for-platform/)
