# 16 · Platform Project 04 — Internal Developer Platform

> The capstone of the core curriculum. Projects 1–3 built the *foundations* — a safe
> cluster, GitOps delivery, and observability. Phase 12 taught you the *parts* of an
> Internal Developer Platform — Backstage, golden paths, templates, a platform CLI.
> **This project assembles them into one working IDP**: a developer opens a portal,
> clicks "create service," and minutes later has a repo, a pipeline, a GitOps
> deployment, a namespace, secrets, and dashboards — all on the platform you built.

**This is a project, not a lesson.** It integrates everything so far into the
self-service product that is the whole point of platform engineering.

➡️ **[Open the project: Internal Developer Platform](./internal-developer-platform/README.md)**

## At a glance

| | |
|---|---|
| **Goal** | A Backstage-based IDP that takes a developer from "I need a service" to "it's running in production" through self-service. |
| **You'll use** | Backstage & golden paths (Phase 12), GitOps (Project 2), observability (Project 3), the cluster foundation (Project 1). |
| **Pass 1 (now)** | Run Backstage locally, register a software catalog, scaffold a service from a **golden-path template**, and see it flow into the GitOps config repo. Free. |
| **Pass 2 (later)** | Deploy Backstage on GKE with GitHub auth, wire the ArgoCD/Kubernetes/Grafana/Cost plugins, and render TechDocs. |
| **Deliverable** | A working IDP with two golden-path templates, a catalog, and a documented zero-to-production onboarding journey. |
| **Effort** | ~12–20 hours. |

## Why this project?

Everything in this course has been building to a single idea from
[Module 01.1](../01-platform-foundations/01-what-is-platform-engineering/README.md):
a platform is a **product** that reduces developers' cognitive load. Projects 1–3 gave
you powerful capabilities — but a developer still had to understand Terraform, ArgoCD,
Kustomize, Kyverno, ESO, and OpenTelemetry to use them. **This project hides all of
that behind a golden path.** The developer answers a short form; the platform does the
rest. That is the difference between "we have Kubernetes" and "we have a platform."

It's also your strongest portfolio piece: a demonstrable IDP that onboards a team from
zero to a production deployment, built on reproducible foundations.

Start here: **[internal-developer-platform/](./internal-developer-platform/README.md)**.

---

_Previous:_ [15 · Developer Experience and IDP](../15-developer-experience-and-idp/)
· _Next:_ [17 · Platform SRE](../17-platform-sre/)
