# 08 · GitOps

> You have containers, a cluster, infrastructure as code, CI pipelines, and a way
> to package Kubernetes manifests. The missing piece is **how declared state
> actually, continuously, and safely reaches the cluster** — without a human
> running `kubectl apply` and without handing production credentials to a CI job.
> That piece is GitOps: Git becomes the single source of truth, and an in-cluster
> agent continuously reconciles the live cluster toward what Git says.

**Phase 7 · 6 modules · ~10–14 hours**

## Why GitOps?

By now you can build and package software, but *delivery* is still fragile. The
most common way teams ship to Kubernetes is some variation of "a CI job runs
`kubectl apply` with cluster-admin credentials." That approach has four structural
problems, and GitOps fixes all four:

- **No source of truth.** The live cluster and your manifests drift apart. Someone
  hotfixes a replica count at 2 a.m., nobody writes it down, and now "what's
  actually running" is a mystery. With GitOps, Git *is* the state; the cluster is
  a cache of it.
- **No audit trail.** "Who changed this, when, and why?" has no answer when changes
  are imperative `kubectl` commands. With GitOps, every change is a reviewed,
  attributable commit — change management you get for free.
- **A security nightmare.** Push-based CI needs long-lived cluster credentials
  sitting in your pipeline, reachable from the internet. GitOps **pulls** from
  inside the cluster, so those credentials never leave it.
- **No self-healing.** When reality diverges from intent, nothing notices. GitOps
  runs a reconciliation loop — the same idea that makes Kubernetes self-healing
  (Phase 3) — now applied to *delivery itself*.

This phase is also the direct setup for **Project 2**: immediately after it you
build a full multi-environment, multi-team GitOps platform. Everything here —
principles, Argo CD, ApplicationSets, promotion, secrets — is a component you will
assemble there. Learn it well; you are about to use all of it.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [GitOps Principles](./01-gitops-principles/) | The four OpenGitOps principles; push vs pull; where CI ends and CD begins; drift and self-healing as a reconcile loop. | A hand-built reconcile loop that heals drift — no GitOps tool. |
| 2 | [Argo CD Fundamentals](./02-argocd-fundamentals/) | Argo CD architecture; the Application resource; health vs sync status; prune, self-heal, and sync options. | Argo CD installed on kind plus an auto-syncing Application. |
| 3 | [Argo CD ApplicationSets](./03-argocd-applicationsets/) | Generators (list, git, matrix); templating many Applications; the app-of-apps pattern. | An ApplicationSet and an app-of-apps generating multiple apps. |
| 4 | [Multi-Environment GitOps](./04-multi-environment-gitops/) | Folder vs branch strategy; promotion by PR; sync waves; rollback by revert. | A base/overlays dev→staging→prod layout with sync waves. |
| 5 | [Secrets in GitOps](./05-secrets-in-gitops/) | Why plaintext secrets can't live in Git; Sealed Secrets, ESO, Vault, SOPS; why ESO wins. | An ExternalSecret syncing a secret from a backend into the cluster. |
| 6 | [GitOps Maturity Model](./06-gitops-maturity-model/) | The five maturity levels; honest self-assessment; choosing the next step. | A maturity rating with a concrete, prioritized next step. |

Work them in order. The principles module builds the reconcile loop by hand so the
tools that follow are demystified; each later module adds one production capability
on top.

## Learning objectives

By the end of this phase you will be able to:

- Explain GitOps from first principles — the four principles, pull over push, and
  drift detection as a reconciliation loop — to a skeptical engineer.
- Install and operate Argo CD, and model a deployment as an `Application` with the
  right sync policy, health, and prune/self-heal behavior.
- Scale GitOps across many apps, clusters, and environments with ApplicationSets
  and the app-of-apps pattern instead of copy-pasted manifests.
- Design a multi-environment config repository with a folder-per-environment layout,
  promotion by pull request, ordered sync waves, and rollback by Git revert.
- Keep secrets out of Git safely, compare the four mainstream approaches, and
  implement the recommended one (External Secrets Operator).
- Assess the GitOps maturity of a real platform and name the single highest-value
  next step.

## Prerequisites

- [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — especially
  the reconciliation loop, objects (`spec`/`status`), RBAC, and namespaces. GitOps
  is that loop applied to delivery, so the mental model must be solid.
- [Phase 6 · Kubernetes Package Management](../07-kubernetes-package-management/) —
  Helm and Kustomize. Argo CD renders both, and the promotion labs use Kustomize
  overlays.
- Everything from [`00-orientation/environment-setup.md`](../00-orientation/environment-setup.md):
  Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). The labs run **free** on
  a local kind cluster with Argo CD installed from upstream manifests — no cloud
  account and no spend required.

## A note on the labs

These labs are cumulative by design. You install Argo CD once and keep building on
it: an Application, then an ApplicationSet, then a multi-environment promotion
layout, then secrets. By the end you'll have, on your laptop, a miniature of the
exact platform you build for real in
[Project 2 · GitOps Platform](../09-platform-project-02/). Keep the config repo you
create — you'll reuse the pattern.

---

Start with [**01 · GitOps Principles →**](./01-gitops-principles/)
