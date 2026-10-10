# 09 · Platform Project 02 — GitOps Platform

> Your second platform build. In [Project 1](../04-platform-project-01/) you built a
> multi-team cluster foundation. Now you'll put **Git in charge of it**: a
> multi-environment, multi-team GitOps platform where ArgoCD continuously reconciles
> the cluster toward declarative config, secrets live outside Git, and changes
> promote dev → staging → prod by pull request.

**This is a project, not a lesson.** It consolidates GitOps (Phase 7), package
management (Phase 6), and CI/CD (Phase 5) into one buildable system — and it's the
delivery backbone every later project runs on.

➡️ **[Open the project: GitOps Platform](./gitops-platform/README.md)**

## At a glance

| | |
|---|---|
| **Goal** | A GitOps platform that delivers all cluster and app config from Git, safely, for multiple teams and environments. |
| **You'll use** | GitOps + ArgoCD (Phase 7), Kustomize (Phase 6), CI promotion (Phase 5), the Project 1 foundation. |
| **Pass 1 (now)** | Build it locally on `kind` + ArgoCD + a Git config repo — app-of-apps, ApplicationSets, overlays, self-healing, promotion by PR. Free. |
| **Pass 2 (later)** | Harden to production: ESO + GCP Secret Manager, Kyverno signed-image policy, CI that writes digests to the config repo, notifications. |
| **Deliverable** | A reproducible `config-repo` + bootstrap + architecture doc + ADRs + runbooks. |
| **Effort** | ~8–12 hours for Pass 1. |

## Why a project here?

GitOps only clicks when you *operate* it: watch ArgoCD heal a cluster after you
delete a resource, promote a change by merging a PR, and roll back by reverting a
commit. This project also produces a portfolio-grade `config-repo` — the exact shape
of a real platform's source of truth — and it's the foundation the Observability
(Project 3) and IDP (Project 4) builds deliver onto.

Start here: **[gitops-platform/](./gitops-platform/README.md)**.

---

_Previous:_ [08 · GitOps](../08-gitops/)
· _Next:_ [10 · Kubernetes Advanced](../10-kubernetes-advanced/)
