# ADR-003 — Why ArgoCD over Flux

## Status

Accepted
Date: 2026-10-10

## Context

The GitOps platform needs a reconciliation engine that watches Git and continuously
converges the cluster toward the declared state. The two leading CNCF-graduated
options are **Argo CD** and **Flux**. Both implement the four GitOps principles well;
the decision is about fit for a course and for a multi-team platform that needs a
clear operator experience.

Constraints: multiple teams and environments; a desire for a visible, teachable
model of sync/health/drift; strong support for both Helm and Kustomize; and patterns
(app-of-apps, ApplicationSets) that scale to many applications.

## Decision

We will use **Argo CD** as the GitOps engine.

## Consequences

- **Easier:** a first-class UI and CLI make sync status, health, and diffs visible —
  excellent for learning and for day-2 operations; **ApplicationSets** and the
  **app-of-apps** pattern scale cleanly to many apps/clusters; native support for
  Kustomize, Helm, and plain manifests.
- **Easier:** a large ecosystem (notifications, image updater, Rollouts) to grow into
  (GitOps maturity Level 4).
- **Harder / trade-offs:** ArgoCD is a larger, more centralized system than Flux's
  set of controllers; its `Application` CRD is an ArgoCD-specific abstraction (Flux
  leans on native `Kustomization`/`HelmRelease` controllers). Teams already deep in
  the Flux/Toolkit model may prefer it.

## Alternatives considered

- **Flux CD** — excellent, composable, GitOps-pure controllers; lighter and very
  Kubernetes-native. A completely valid choice. We pick Argo CD for its visibility
  (UI/CLI), the ApplicationSet/app-of-apps patterns, and its teachability for a
  course.
- **Manual `kubectl apply` + scripts** — rejected: no continuous reconciliation, no
  self-healing, weak audit trail (this is the Project 1 state we're improving on).

## References

- [Argo CD documentation](https://argo-cd.readthedocs.io/)
- [Flux documentation](https://fluxcd.io/)
- [OpenGitOps principles](https://opengitops.dev/)
