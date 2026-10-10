# Architecture — GitOps Platform

This document describes the GitOps platform: what it's made of, how config flows from
Git to the cluster, and the reasoning behind the design. Decisions with meaningful
trade-offs are captured as [ADRs](./decisions/).

## Problem statement

[Project 1](../../../04-platform-project-01/) gave three teams a safe cluster
foundation — but it was applied by hand with `kubectl`. Hand-applied clusters drift,
lack an audit trail, and don't scale across environments. This project makes **Git
the single source of truth**: every change is a reviewed commit, the cluster
continuously reconciles toward Git, and promotion across environments is a pull
request — not a privileged human running commands against production.

## Design goals

- **Single source of truth.** The cluster's desired state lives in one Git repo.
- **Continuous reconciliation.** ArgoCD closes any gap between Git and the cluster,
  and self-heals drift.
- **Safe promotion.** Changes flow dev → staging → prod by PR, with prod behind a
  manual gate.
- **No secrets in Git.** Secrets come from a secret manager via ESO, never plaintext.
- **No copy-paste.** ApplicationSets generate per-environment Applications from one
  template, so adding a service or environment is a small, reviewable change.
- **Auditable & reversible.** Every change is a commit; rollback is `git revert`.

## How config flows

```text
   PR → review → merge into config-repo
        │
        ▼
   ArgoCD application-controller polls (or is webhook-notified) the config repo,
   computes the diff between Git (desired) and the cluster (actual), and:
        ├─ dev / staging:  auto-syncs and self-heals
        └─ prod:           reports OutOfSync and WAITS for a human to sync
        │
        ▼
   Kubernetes resources created/updated (Kustomize overlays rendered by ArgoCD)
```

This is the reconciliation loop from
[Module 03.1](../../../03-kubernetes-fundamentals/01-kubernetes-architecture/README.md),
applied to delivery: desired state (Git) vs actual state (cluster), reconciled
continuously.

## Component inventory

| Component | Role | Pass | Introduced in |
|-----------|------|:----:|---------------|
| ArgoCD | The GitOps engine; watches Git, reconciles the cluster | **1** | [Phase 7](../../../08-gitops/02-argocd-fundamentals/) |
| app-of-apps root Application | One Application that creates all the others | **1** | [Phase 7](../../../08-gitops/03-argocd-applicationsets/) |
| ApplicationSets | Generate one Application per team/service/env | **1** | [Phase 7](../../../08-gitops/03-argocd-applicationsets/) |
| Kustomize overlays | Per-environment config (dev/staging/prod) | **1** | [Phase 6](../../../07-kubernetes-package-management/03-kustomize/) |
| config-repo | The single source of truth in Git | **1** | [Phase 7](../../../08-gitops/) |
| External Secrets Operator | Syncs secrets from Secret Manager into the cluster | 2 | [Phase 10](../../../13-security-and-policy-engineering/) |
| GCP Secret Manager | The external source of truth for secrets | 2 | [Phase 10](../../../13-security-and-policy-engineering/) |
| Kyverno (verify images) | Admits only signed images from the allowed registry | 2 | [Phase 10](../../../13-security-and-policy-engineering/) |
| CI promotion | Writes the new image digest to a config-repo PR | 2 | [Phase 5](../../../06-cicd-for-platform-teams/) |

## The config repo

```text
config-repo/
├── platform/            # cluster-wide platform config, synced by ArgoCD (Pass 1)
│   ├── namespaces.yaml          # team-a-{dev,staging,prod}, team-b-{...}, with Pod Security
│   ├── resourcequotas.yaml      # per-namespace budgets (from Project 1)
│   └── pass2/                   # NOT synced in Pass 1 (needs Kyverno/ESO CRDs)
│       ├── kyverno-verify-images.yaml  # Pass 2: only signed ghcr.io/org images
│       └── eso-example.yaml            # Pass 2: ExternalSecret + SecretStore
└── apps/
    ├── team-a/service-1/
    │   ├── base/                # deployment + service + kustomization
    │   └── overlays/
    │       ├── dev/             # replicas=1, image tag dev
    │       ├── staging/         # replicas=2
    │       └── prod/            # replicas=3
    └── team-b/service-2/        # same shape
```

**Folder strategy, not branch strategy.** Every environment is a *folder*
(`overlays/dev`, `overlays/staging`, `overlays/prod`) on the same branch, not a
long-lived `dev`/`prod` branch. Folders make the full state of every environment
visible in one place and avoid merge-drift between branches — see
[ADR-012](./decisions/ADR-012-folder-over-branch-strategy.md).

## Bootstrapping: app-of-apps + ApplicationSets

You `kubectl apply` **one** thing — the root Application — and it pulls in everything
else:

```text
   root-app.yaml (app-of-apps)
        ├── syncs config-repo/platform/        (namespaces, quotas, policy)
        ├── applies apps-nonprod-appset.yaml    → generates dev + staging Applications (auto-sync)
        └── applies apps-prod-appset.yaml       → generates prod Applications (manual gate)
```

The **ApplicationSets** use a Git directory generator over
`apps/*/*/overlays/<env>` to create one Application per service per environment.
Adding a service means adding a folder — the ApplicationSet generates its
Applications automatically. See
[ADR-013](./decisions/ADR-013-app-of-apps-and-applicationsets.md).

## Promotion and rollback

- **Promotion** is a pull request that changes an overlay (typically the image tag/
  digest). Merge to `main` → dev and staging auto-sync → a human clicks sync (or
  approves) for prod. In Pass 2, CI opens that PR automatically with the new digest.
- **Rollback** is `git revert` of the offending commit; ArgoCD converges the cluster
  back to the previous state. The Git history *is* the deployment history.

## Security posture

- **No plaintext secrets in Git.** ESO pulls from GCP Secret Manager and materializes
  Kubernetes `Secret`s in-cluster (Pass 2). Sealed Secrets / SOPS are alternatives —
  see [ADR-014](./decisions/ADR-014-secrets-strategy.md).
- **Signed images only.** A Kyverno `verifyImages` policy admits only
  Cosign-signed images from the allowed registry (Pass 2).
- **Least-privilege delivery.** ArgoCD is the only identity that writes to the
  cluster for app config; humans change the cluster by changing Git, not by direct
  `kubectl`.
- **Prod manual gate.** Production never auto-applies; a human reviews the diff and
  syncs.

## Known limitations

- Pass 1 uses unsigned public images and no ESO; those guarantees become structural
  in Pass 2.
- Single cluster. Multi-cluster GitOps (ApplicationSet cluster generator, Cluster
  Mesh) is [Phase 8](../../../10-kubernetes-advanced/05-multi-cluster-kubernetes/)
  and Capstone 3.
- No progressive delivery yet (Argo Rollouts/Flagger) — that's GitOps maturity
  Level 4 ([Module 08.6](../../../08-gitops/06-gitops-maturity-model/)).

## Production considerations

- Protect the config repo: required reviews, CODEOWNERS, signed commits, branch
  protection. The repo is now your production control plane.
- Put prod behind both a manual ArgoCD sync and PR review; consider separate repos or
  CODEOWNERS paths for `overlays/prod`.
- Monitor ArgoCD itself (sync latency, OutOfSync count, failed syncs) and alert on
  drift — ArgoCD is now tier-1 infrastructure (Project 3 adds the observability).
- Back up ArgoCD's state and the config repo; practice restoring from Git.

## Decisions

See the [ADRs](./decisions/):

- [ADR-003 — Why ArgoCD over Flux](./decisions/ADR-003-why-argocd.md)
- [ADR-012 — Why a folder strategy over a branch strategy](./decisions/ADR-012-folder-over-branch-strategy.md)
- [ADR-013 — Why app-of-apps + ApplicationSets](./decisions/ADR-013-app-of-apps-and-applicationsets.md)
- [ADR-014 — Why External Secrets Operator over committing secrets](./decisions/ADR-014-secrets-strategy.md)
