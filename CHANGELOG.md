# Changelog

All notable changes to this course are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Because this is a course rather than a versioned software library, entries track
curriculum progress. See the [ROADMAP](./ROADMAP.md) for the full plan and status.

## [Unreleased]

### Planned

- Phase 2 — Containerization (module `02`).
- Phase 3 — Kubernetes Fundamentals (module `03`).
- Remaining phases and projects per the [ROADMAP](./ROADMAP.md).

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

[Unreleased]: ../../compare/v0.1.0...HEAD
[0.1.0]: ../../releases/tag/v0.1.0
