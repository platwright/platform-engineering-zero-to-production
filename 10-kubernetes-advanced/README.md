# 10 · Kubernetes Advanced

> You can already run workloads on Kubernetes (Phase 3) and deliver them with Helm
> and GitOps (Phases 7–8, Project 2). This phase is where you stop being a *user* of
> Kubernetes and become a *builder of platforms on top of it*: you teach the API new
> nouns, encode your operational runbooks as software, enforce guardrails at the
> moment a request is admitted, and operate across many clusters. This is the
> machinery behind every real Internal Developer Platform.

**Phase 8 · 5 modules · ~12–18 hours**

## Why extend Kubernetes?

In Project 1 you onboarded a team **by hand**: create a namespace, label it, apply a
`ResourceQuota` and `LimitRange`, wire up RBAC, and hope nobody forgot a step. That
runbook works for three teams. It does not work for three hundred, and it does not
survive the 2am mistake where someone skips the quota and a runaway Deployment eats
the cluster.

The Kubernetes answer is not "write a bigger shell script." It is to **extend the
platform itself** so the right thing happens automatically:

- **Custom Resource Definitions (CRDs)** let you add your own objects — an
  `Environment`, a `Database`, a `TenantApp` — to the same API every tool already
  speaks. Your platform's concepts become first-class API citizens.
- **Operators** encode your runbook as a controller: the reconciliation loop from
  Module 03.1, now driving *your* resources. "Create a namespace, RBAC, quota, and
  limits for this team" becomes software that never forgets a step and heals drift.
- **Admission control** (webhooks and CEL policies) enforces guardrails *before* an
  object is ever stored — injecting cost labels, requiring security context, or
  rejecting what violates policy — without trusting every developer to remember.
- **API extension patterns** (subresources, field selectors, Server-Side Apply)
  make your custom APIs behave like the built-ins, so `kubectl scale`, HPAs, and
  multi-writer automation Just Work on them.
- **Multi-cluster** is the reality once you have more than one environment, region,
  or tenant boundary — and it changes how you think about desired state and delivery.

Every idea here is the same reconciliation loop you already know, aimed at problems
you previously solved with tickets and tribal knowledge. By the end you will have
turned Project 1's manual onboarding into a running operator.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Custom Resource Definitions](./01-custom-resource-definitions/) | Extend the API without forking core; CRD anatomy; OpenAPI v3 + CEL validation; versioning and the status subresource. | A validated `Environment` CRD applied to kind, accepting good CRs and rejecting bad ones. |
| 2 | [Kubernetes Operators](./02-kubernetes-operators/) | The operator pattern; controller-runtime; requeue strategies; status conditions; owner references and finalizers. | A `NamespaceProvisioner` operator that reconciles namespace, RBAC, quota, and limits from an `Environment`. |
| 3 | [Admission Webhooks](./03-admission-webhooks/) | Mutating vs validating admission; `ValidatingAdmissionPolicy` with CEL; webhook TLS, registration, and failure policy. | A CEL policy that requires cost labels, plus a mutating webhook that injects them automatically. |
| 4 | [API Extension Patterns](./04-api-extension-patterns/) | Subresources (`/status`, `/scale`); field selectors and printer columns; Server-Side Apply; CEL transition rules. | An upgraded `Environment` CRD you can `kubectl scale`, filter by field, and apply server-side. |
| 5 | [Multi-Cluster Kubernetes](./05-multi-cluster-kubernetes/) | Why multi-cluster; topologies; the management-cluster pattern; Cluster API; fleet delivery with Argo CD. | Two kind clusters managed from one context, with an ApplicationSet fanning an app out to both. |

Work them in order — each builds on the last, and Modules 2 and 4 both extend the
CRD you write in Module 1.

## Learning objectives

By the end of this phase you will be able to:

- Extend the Kubernetes API with your own resources, validated by OpenAPI v3 schemas
  and CEL rules, and reason about versioning and the status subresource.
- Build a controller with controller-runtime that reconciles a custom resource into
  real cluster state, reports status conditions, and cleans up with finalizers.
- Enforce platform guardrails at admission time, choosing CEL policies first and
  webhooks only when you genuinely need a server.
- Make custom APIs behave like built-ins using subresources, field selectors, and
  Server-Side Apply.
- Explain multi-cluster topologies and operate a small fleet from a management
  cluster, including declarative delivery with an ApplicationSet.

## Prerequisites

- [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — especially
  [Module 03.1](../03-kubernetes-fundamentals/01-kubernetes-architecture/)
  (the reconciliation loop) and RBAC, quotas, and limits.
- [Project 1 · Container Platform Foundation](../04-platform-project-01/) — you'll
  automate the manual team-onboarding runbook you built there.
- [Phase 8 · GitOps](../08-gitops/) for the Argo CD and ApplicationSet concepts used
  in Module 5.
- Everything from [Module 00 · Orientation](../00-orientation/): Docker, `kubectl`,
  and [kind](https://kind.sigs.k8s.io/). Module 2's operator lab additionally needs
  a Go toolchain (the lab is explicit about what requires it).

Every lab runs **free** on local kind clusters — there is no cloud spend in this
phase.

## A note on the labs

These labs produce **reusable platform machinery**, not throwaway demos. The
`Environment` CRD from Module 1 is extended by Modules 2 and 4; the cost-label
webhook from Module 3 is the enforcement half of the FinOps work in Phase 18. Keep
the manifests and the operator — they are the seed of a real control plane, and a
strong portfolio piece that shows you can *build* on Kubernetes, not just run things
on it.

---

Start with [**01 · Custom Resource Definitions →**](./01-custom-resource-definitions/)
