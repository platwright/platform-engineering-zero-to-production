# Changelog

All notable changes to this course are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Because this is a course rather than a versioned software library, entries track
curriculum progress. See the [ROADMAP](./ROADMAP.md) for the full plan and status.

## [Unreleased]

### Planned

- Phase 5 — CI/CD for Platform Teams (module `06`).
- Phase 6 — Kubernetes Package Management (module `07`).
- Remaining phases and projects per the [ROADMAP](./ROADMAP.md).

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

[Unreleased]: ../../compare/v0.2.0...HEAD
[0.2.0]: ../../releases/tag/v0.2.0
[0.1.0]: ../../releases/tag/v0.1.0
