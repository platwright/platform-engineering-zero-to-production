# 04 · Platform Project 01 — Container Platform Foundation

> Your first real platform build. You've learned the mindset (Phase 1), how
> containers work (Phase 2), and how to operate Kubernetes (Phase 3). Now you'll
> combine them into the **foundation other teams build on**: a multi-team cluster
> with isolation, guardrails, and a hardened golden-path workload.

**This is a project, not a lesson.** It consolidates everything so far into one
buildable system and becomes the base you keep upgrading in later phases.

➡️ **[Open the project: Container Platform Foundation](./container-platform-foundation/README.md)**

## At a glance

| | |
|---|---|
| **Goal** | A production-grade container platform foundation teams can deploy onto safely. |
| **You'll use** | Containers (Phase 2), Kubernetes (Phase 3), product thinking (Phase 1). |
| **Pass 1 (now)** | Build it locally on `kind` — namespaces, RBAC, quotas, a hardened workload. Free. |
| **Pass 2 (later)** | Upgrade each piece to production (Terraform GKE, CI build→scan→sign→push, Kyverno, ESO, Cilium) as those phases teach them. |
| **Deliverable** | A reproducible foundation + architecture doc + ADRs + onboarding guide. |
| **Effort** | ~8–12 hours for Pass 1; Pass 2 is spread across later phases. |

## Why a project here?

Theory is scaffolding; a project is where it becomes skill. Reading about RBAC and
ResourceQuotas is not the same as standing up three team namespaces, wiring
least-privilege access, and watching a quota stop a runaway deployment. This
project also gives you your first **portfolio piece**: a documented, reproducible
platform foundation.

Start here: **[container-platform-foundation/](./container-platform-foundation/README.md)**.

---

_Previous:_ [03 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/)
· _Next:_ [05 · Infrastructure as Code](../05-infrastructure-as-code/)
