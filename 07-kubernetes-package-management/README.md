# 07 · Kubernetes Package Management

> You can write Kubernetes YAML. The problem is that a real platform has to ship
> *the same workload* to dozens of teams and a handful of environments — each with
> slightly different replicas, images, and limits — without copy-pasting manifests
> and praying they stay in sync. This phase is about **packaging**: turning raw
> manifests into versioned, parameterized, distributable products that teams consume
> on demand. It is where the "golden path" you keep hearing about stops being a slide
> and becomes an artifact with a version number.

**Phase 6 · 5 modules · ~8–12 hours**

## Why this phase?

By now you can hand-write a Deployment, a Service, and an HPA. That works for one
app in one environment. It falls apart the moment you have **N apps × M
environments**: every manifest is copied, every copy drifts, and a security fix in
the "standard" Deployment has to be pasted into forty repos by hand. This is the
single most common way platform good intentions rot — the paved road exists, but
there is no mechanism to *distribute* it or *update* it.

Package management is that mechanism. It gives you three things raw YAML cannot:

- **Parameterization** — one definition, many configurations. Dev gets one replica
  and a debug image; prod gets three replicas, tight limits, and an HPA — from the
  *same* source of truth.
- **Packaging and versioning** — a workload becomes a named, versioned artifact
  (`platform-app-1.4.2`) you can publish, pin, roll back, and audit, exactly like a
  library dependency.
- **Distribution** — that artifact lives in a registry, so "adopt the golden path"
  becomes `helm install` instead of "clone this repo and edit nine files."

This is a **product** concern, not a YAML concern. The hardened chart you build in
Module 07.2 is the literal thing a product team consumes to get a secure,
observable, autoscaled service for free — the payload behind the self-service
experience you'll wire up in the IDP phase. Treating your workload template as a
distributed, versioned package is what lets a two-person platform team keep a
hundred services on a consistent, secure baseline.

We teach the **problem before the tool** throughout:

- **Why templating exists** — you'll feel the pain of duplicated manifests *before*
  reaching for Helm.
- **Templating vs overlays** — Helm *generates* YAML from templates; Kustomize
  *patches* YAML that already exists. Different philosophies, different sweet spots.
- **When each wins** — and how to combine them instead of fighting a religious war.
- **Distribution as a first-class concern** — charts and other artifacts travel
  through OCI registries, the same place your container images already live.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Helm Fundamentals](./01-helm-fundamentals/) | Charts, releases, repositories; the install/upgrade/rollback/uninstall lifecycle; release history and the values hierarchy. | A chart installed, upgraded, and rolled back on kind — with its revision history read back. |
| 2 | [Helm Chart Development](./02-helm-chart-development/) | Named templates and helpers, `values.schema.json` validation, hooks, `helm test`, and packaging a chart teams can consume. | A hardened `platform-app` chart that passes `helm lint`, renders cleanly, and self-tests. |
| 3 | [Kustomize](./03-kustomize/) | Bases and overlays, strategic-merge and JSON patches, generators, and transformers — templating-free configuration. | A base plus `dev`/`prod` overlays applied with `kubectl apply -k`. |
| 4 | [Helm vs Kustomize](./04-helm-vs-kustomize/) | Templating vs overlays; when each wins; combining a Helm base with a Kustomize overlay; what ArgoCD supports. | The same app deployed three ways (Helm, Kustomize, Helm+Kustomize) and compared. |
| 5 | [OCI Artifacts and Distribution](./05-oci-artifacts-and-distribution/) | OCI as universal artifact storage; `helm push`/`pull oci://`; ORAS; SBOMs and attestations as artifacts. | A chart packaged, pushed to a local OCI registry, and pulled back to install. |

Work them in order — each builds on the last. Together they take you from "what is a
chart?" to "here's a hardened, versioned workload package a platform team publishes
to a registry and every team installs."

## Learning objectives

By the end of this phase you will be able to:

- Explain, from first principles, the duplication-and-drift problem that package
  management solves, independent of any specific tool.
- Install, upgrade, roll back, and inspect the history of a Helm release, and reason
  about the values hierarchy that configures it.
- Author a reusable, **hardened-by-default** Helm chart — non-root, read-only
  root filesystem, dropped capabilities — with schema validation and a `helm test`.
- Use Kustomize bases and overlays to produce per-environment variants without
  templating, using strategic-merge and JSON patches, generators, and transformers.
- Choose between Helm and Kustomize for a given job, and combine them deliberately.
- Distribute charts and related artifacts (SBOMs, attestations) through OCI
  registries, and describe the platform patterns that rely on them.

## Prerequisites

- [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — you must be
  comfortable with Deployments, Services, HPAs, probes, and `kubectl`. This phase
  packages those objects; it does not re-teach them.
- [Phase 1 · Platform Foundations](../01-platform-foundations/) for the product and
  developer-experience lenses — a chart is only useful if teams *adopt* it.
- Everything in [`00-orientation/environment-setup.md`](../00-orientation/environment-setup.md):
  Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). You'll additionally
  install **Helm** and **Kustomize** (and `kubectl` already bundles a Kustomize
  build). Module 07.5 uses a local `registry:2` container as an OCI registry.

## A note on cost

**These labs are designed to cost nothing.** Everything runs on a local
[kind](https://kind.sigs.k8s.io/) cluster with local Helm and Kustomize. The OCI
distribution lab uses a throwaway [`registry:2`](https://hub.docker.com/_/registry)
container as your private registry, so there is no cloud spend and no account to
create. Where a step *could* use a hosted registry such as GHCR, it's marked
**optional** with a short note on accounts and cost — the local registry is the
primary path. Every lab that creates a cluster, a registry, or releases ends with a
mandatory cleanup step. Never skip it.

---

Start with [**01 · Helm Fundamentals →**](./01-helm-fundamentals/)
