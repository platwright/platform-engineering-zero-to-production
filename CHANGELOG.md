# Changelog

All notable changes to this course are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Because this is a course rather than a versioned software library, entries track
curriculum progress. See the [ROADMAP](./ROADMAP.md) for the full plan and status.

## [Unreleased]

### Planned

- Phase 11 — Kubernetes Networking (module `14`).
- Phase 12 — Developer Experience and IDP (module `15`).
- Remaining phases and projects per the [ROADMAP](./ROADMAP.md).

## [0.4.0] — 2026-10-11

Observability through Security: two full phases plus the observability platform
project.

### Added

- **Module 11 — Observability Engineering** (complete) — 8 submodules + labs:
  observability fundamentals, OpenTelemetry, metrics with Prometheus, logging with
  Loki, distributed tracing with Tempo, Grafana dashboards, SLOs & error budgets,
  and platform observability strategy. Runnable local/Compose labs with collector
  configs, PromQL/LogQL/TraceQL snippets, a Grafana dashboard (JSON + Jsonnet), and
  Sloth SLO definitions.
- **Project 3 — Observability Platform** (complete) — a full OTel + Prometheus/Loki/
  Tempo/Grafana stack with a DaemonSet + gateway collector topology (tail sampling),
  Grafana datasources with trace/log/metric correlation, a Platform Overview
  Dashboard as code, a Sloth SLO, and a sample burn-rate alert. Includes an
  architecture doc, four ADRs, a staged build guide, onboarding guide, runbooks, and
  bootstrap/cleanup scripts.
- **Module 13 — Security and Policy Engineering** (complete) — 8 submodules + labs:
  security principles (defence-in-depth, CIS, OWASP K8s Top 10), RBAC deep dive,
  policy-as-code with Kyverno, secret management (Vault + ESO), supply-chain security
  (SLSA, Syft, Grype), image signing & verification (Cosign + Kyverno verifyImages),
  runtime security (Falco), and zero trust (SPIFFE, mTLS, Cilium L7). Ties back to
  Project 1's ADR-004/ADR-005 and Project 2's signed-image policy.

### Changed

- `ROADMAP.md` updated: modules `11`–`13` marked complete with per-submodule links.

## [0.3.0] — 2026-10-10

CI/CD through Kubernetes Advanced: five more modules, including the GitOps platform
project.

### Added

- **Module 06 — CI/CD for Platform Teams** (complete) — 6 submodules + labs:
  platform CI/CD fundamentals, GitHub Actions deep dive, reusable workflows &
  composite actions, pipeline templates as a product, container build pipelines
  (`lint → test → build → scan → sign → push`), and IaC pipelines. Runnable,
  actionlint-clean workflow starters, a composite action, OIDC keyless-auth
  examples, and a Terraform plan-on-PR pipeline.
- **Module 07 — Kubernetes Package Management** (complete) — 5 submodules + labs:
  Helm fundamentals, Helm chart development, Kustomize, Helm vs Kustomize, and OCI
  artifacts & distribution. Includes a hardened `platform-app` Helm chart
  (`helm lint`/`template` clean) and base+overlay Kustomize examples.
- **Module 08 — GitOps** (complete) — 6 submodules + labs on local kind + ArgoCD:
  GitOps principles, ArgoCD fundamentals, ApplicationSets, multi-environment GitOps
  (folder strategy + sync waves), secrets in GitOps (ESO/Sealed Secrets/SOPS/Vault),
  and a GitOps maturity model. Includes a hand-built reconcile loop and real ArgoCD
  manifests.
- **Project 2 — GitOps Platform** (complete) — a multi-team, multi-environment
  GitOps platform: an app-of-apps root, two ApplicationSets (non-prod auto-sync vs a
  prod manual gate), platform namespaces/quotas, and base+overlay manifests for two
  teams across dev/staging/prod (Kustomize overlays render with replicas 1/2/3).
  Includes an architecture doc, four ADRs, a staged build guide (promotion by PR,
  self-heal, rollback), onboarding guide, runbooks, bootstrap/cleanup scripts, and
  Pass-2 scaffolding (ESO + Kyverno signed-image policy).
- **Module 10 — Kubernetes Advanced** (complete) — 5 submodules + labs: CRDs (with
  CEL validation and a status subresource), operators (a compiling controller-runtime
  `NamespaceProvisioner`), admission webhooks (a CEL `ValidatingAdmissionPolicy` plus
  a mutating webhook), API extension patterns (subresources, SSA, field selectors),
  and multi-cluster Kubernetes (two kind clusters + an ApplicationSet cluster
  generator).

### Changed

- `ROADMAP.md` updated: modules `06`–`10` marked complete with per-submodule links.

## [0.2.0] — 2026-10-09

Containers through Infrastructure as Code: four more modules, including the first
hands-on project.

### Added

- **Module 02 — Containerization** (complete) — 7 submodules, each a full lesson
  and lab: container fundamentals (namespaces/cgroups/OCI), Dockerfiles and image
  building, container networking, container storage, container security, registries,
  and multi-platform builds & optimization. Runnable starter files (Dockerfiles,
  a Go app, multi-arch + hardened builds).
- **Module 03 — Kubernetes Fundamentals** (complete) — 9 submodules, each a full
  lesson and lab on a free local `kind` cluster: architecture, workloads, services
  & networking, configuration, storage, RBAC, resource management, health &
  scheduling, and a debugging lab with five pre-broken manifests.
- **Project 1 — Container Platform Foundation** (complete) — a multi-team cluster
  foundation built in two passes: a free local Pass 1 (namespaces with Pod Security
  Admission, least-privilege RBAC, LimitRanges/ResourceQuotas, a hardened workload,
  bootstrap/cleanup scripts) and a Pass 2 production roadmap. Includes an
  architecture doc, four ADRs, a staged build guide, an onboarding guide, runbooks,
  and CI/Terraform/Helm scaffolding.
- **Module 05 — Infrastructure as Code** (complete) — 7 submodules, each a full
  lesson and cost-free local lab: IaC principles, Terraform fundamentals, state
  management, modules, testing & quality (Terratest, tfsec/Checkov, OPA/Conftest),
  Crossplane, and IaC patterns for platform teams. Starter `.tf` modules, a Go
  Terratest, Rego policy, and Crossplane manifests.

### Changed

- `ROADMAP.md` updated: modules `02`–`05` marked complete with per-submodule links.

## [0.1.0] — 2026-10-09

The foundation release: repository scaffolding plus the first two modules.

### Added

- **Repository foundation**
  - Root documentation: `README.md`, `ROADMAP.md`, `CONTRIBUTING.md`,
    `CODE_OF_CONDUCT.md`, `SECURITY.md`, this `CHANGELOG.md`, and a dual
    `LICENSE` (CC BY-SA 4.0 for content, MIT for code).
  - Tooling config: `.gitignore`, `.gitattributes`, `.editorconfig`,
    `.markdownlint.json`.
  - `.github/` with CI workflows (Markdown lint, link check), issue templates,
    a pull-request template, and `CODEOWNERS`.
  - `shared/` library scaffolding (terraform-modules, helm-charts,
    github-actions, scripts) and authoring templates (module, lab, ADR,
    progress tracker).
  - `scripts/` with cross-platform prerequisite checks.
  - `diagrams/`, `datasets/`, and `notebooks/` scaffolding.
  - Navigable stubs for every planned phase (`02`–`23`).

- **Module 00 — Orientation** (complete)
  - How to use the course, learning paths and tracks, prerequisites with a
    self-check, environment setup, cloud account setup, a glossary, and the
    `learning-progress.md` tracker.

- **Module 01 — Platform Foundations** (complete)
  - `01` What Is Platform Engineering?
  - `02` Platform as a Product
  - `03` Developer Experience
  - `04` The Internal Developer Platform
  - `05` Platform Team Topology
  - Each with a full lesson and a hands-on lab.

[Unreleased]: ../../compare/v0.4.0...HEAD
[0.4.0]: ../../releases/tag/v0.4.0
[0.3.0]: ../../releases/tag/v0.3.0
[0.2.0]: ../../releases/tag/v0.2.0
[0.1.0]: ../../releases/tag/v0.1.0
