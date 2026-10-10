# ADR-012 — Why a folder strategy over a branch strategy for environments

## Status

Accepted
Date: 2026-10-10

## Context

A multi-environment GitOps platform must represent dev, staging, and prod in Git.
Two common strategies exist:

- **Branch strategy** — a long-lived branch per environment (`dev`, `staging`,
  `prod`); you promote by merging one branch into the next.
- **Folder strategy** — one branch (`main`) with a folder per environment
  (`overlays/dev`, `overlays/staging`, `overlays/prod`); you promote by editing the
  next environment's folder.

Constraints: we want environment state to be obvious and auditable, promotion to be
an explicit and reviewable change, and no accidental drift between environments.

## Decision

We will use a **folder strategy**: every environment is a Kustomize overlay folder on
`main`.

## Consequences

- **Easier:** the full desired state of *every* environment is visible in one place
  on one branch — no checking out branches to compare. Promotion is an explicit diff
  (e.g. "bump prod image to this digest") that a reviewer can read.
- **Easier:** avoids the classic branch-strategy problem where `dev` and `prod`
  branches silently diverge (config merged to one but not the other) and
  cherry-picking becomes error-prone.
- **Harder / trade-offs:** a single branch means environment config isn't isolated by
  branch permissions; you enforce review boundaries with CODEOWNERS/path rules
  instead (e.g. require extra approval for `overlays/prod`). Promotion is a copy/edit
  of values rather than a branch merge.

## Alternatives considered

- **Branch per environment** — intuitive promotion via merge, and branch-level
  permissions. Rejected as the default because divergence between environment
  branches is a well-known source of "it worked in staging" drift, and comparing
  environments requires branch gymnastics.
- **Repo per environment** — strong isolation, but heavy duplication and cross-repo
  promotion friction; reserved for cases with hard regulatory separation.

## References

- [Argo CD — best practices (separate config)](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [Kustomize overlays](https://kubectl.docs.kubernetes.io/references/kustomize/)
