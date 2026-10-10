# Project 2 — GitOps Platform

> Build a complete multi-environment, multi-team GitOps platform using **ArgoCD**:
> Git is the single source of truth, the cluster continuously reconciles toward it,
> secrets never live in Git in plaintext, and changes promote dev → staging → prod
> by pull request with a manual gate on production.

This project sits right after [Phase 7 · GitOps](../../08-gitops/) and builds on the
[Project 1](../../04-platform-project-01/) foundation. As with Project 1, you build
it in **two passes** so you make something real now and grow it into production as
later phases teach each capability.

---

## The two-pass approach

```text
PASS 1 — Build it now (free, local: kind + ArgoCD + a Git config repo)
  • App-of-apps that bootstraps the whole platform from one root Application
  • ApplicationSets that generate one Application per team/service/environment
  • Multi-environment overlays (dev / staging / prod) with Kustomize
  • Auto-sync + self-healing for dev & staging; a MANUAL sync gate for prod
  • Promotion by pull request: edit an overlay → PR → merge → ArgoCD syncs
  • Rollback by reverting a Git commit

PASS 2 — Harden to production (as later phases teach it)
  • Secrets via External Secrets Operator + GCP Secret Manager   → Phase 10 (Security)
  • CI writes the new image digest to the config repo via PR       → Phase 5 (CI/CD)
  • Kyverno: only signed images from ghcr.io/org may run           → Phase 10 (Security)
  • ArgoCD notifications (Slack/email) on sync + drift events       → Phase 9 (Observability)
```

---

## Target architecture

```text
   application-repo (CI, GitHub Actions)
        │  on merge: build → scan → sign → push, then
        │  open a PR that updates the image digest in the config repo
        ▼
   config-repo (Git — the single source of truth)
   ├── platform/      ← namespaces, quotas, RBAC, ESO, Kyverno policy
   └── apps/
       ├── team-a/service-1/{base, overlays/dev,staging,prod}
       └── team-b/service-2/{base, overlays/dev,staging,prod}
        │
        │  ArgoCD watches the config repo and reconciles the cluster
        ▼
   ArgoCD  ──(app-of-apps + ApplicationSets)──►  Kubernetes cluster
        │                                          dev  (auto-sync, self-heal)
        │                                          staging (auto-sync)
        │                                          prod (MANUAL sync gate)
        ▼
   GCP Secret Manager ──► External Secrets Operator ──► Kubernetes Secrets
```

Mapped to the IDP **five planes**
([Module 01.4](../../01-platform-foundations/04-the-internal-developer-platform/README.md)),
this project is the **integration & delivery plane** — the engine that turns "config
in Git" into "running in the cluster."

See [architecture/architecture.md](./architecture/architecture.md) for the full
component inventory and the decisions behind it.

---

## Requirements

From the course outline. The **Pass** column shows what you build now vs the phase
that completes it later.

| # | Requirement | Pass | Taught in |
|---|-------------|------|-----------|
| 1 | App-of-apps bootstraps the entire cluster config | **1** | [Phase 7 · GitOps](../../08-gitops/) |
| 2 | ApplicationSets for team-a and team-b applications | **1** | [Phase 7 · ApplicationSets](../../08-gitops/03-argocd-applicationsets/) |
| 3 | ArgoCD auto-syncs dev; production requires a manual sync gate | **1** | [Phase 7 · Multi-env GitOps](../../08-gitops/04-multi-environment-gitops/) |
| 4 | Promotion pipeline: CI writes the image digest to a config-repo PR | 2 | [Phase 5 · CI/CD](../../06-cicd-for-platform-teams/) |
| 5 | ESO + GCP Secret Manager for all secrets | 2 | [Phase 10 · Security](../../13-security-and-policy-engineering/) |
| 6 | Kyverno policy: only signed images from `ghcr.io/org` allowed | 2 | [Phase 10 · Security](../../13-security-and-policy-engineering/) |

---

## Prerequisites

- Completed [Phase 5](../../06-cicd-for-platform-teams/),
  [Phase 6](../../07-kubernetes-package-management/), and
  [Phase 7](../../08-gitops/), plus the [Project 1](../../04-platform-project-01/)
  foundation.
- Tools: Docker, `kubectl`, `kind`, `git`, and the
  [`argocd` CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/). For
  Pass 2: `gcloud`, `cosign`.
- A **Git host for the config repo.** GitOps needs a Git URL ArgoCD can reach — a
  free GitHub repo is perfect. You'll push the [`config-repo/`](./config-repo/)
  contents there and point ArgoCD at it.

---

## Build it

The full, staged walkthrough is the project's build guide:

➡️ **[Build guide — step by step](./build-guide.md)**

Quick start (after you've pushed `config-repo/` to your own Git host and set its
URL — see the build guide):

```bash
# From this project directory
export CONFIG_REPO_URL="https://github.com/<you>/gitops-config.git"
./scripts/bootstrap.sh      # kind cluster + ArgoCD + the app-of-apps root
# ... watch ArgoCD sync; promote a change; break something and watch it self-heal ...
./scripts/cleanup.sh        # tear everything down
```

---

## Repository layout

```text
gitops-platform/
├── README.md                 # you are here
├── build-guide.md            # the staged build walkthrough
├── architecture/
│   ├── architecture.md       # full architecture + component inventory
│   ├── decisions/            # ADRs (ArgoCD vs Flux, folder vs branch, secrets, app-of-apps)
│   └── diagrams/
├── bootstrap/                # applied once to point ArgoCD at the config repo
│   ├── root-app.yaml         # the app-of-apps root Application
│   ├── apps-nonprod-appset.yaml  # auto-sync dev+staging
│   └── apps-prod-appset.yaml     # manual-gate prod
├── config-repo/              # THE source of truth you push to your Git host
│   ├── platform/             # namespaces, quotas, RBAC, Kyverno, ESO (ArgoCD-synced)
│   └── apps/
│       ├── team-a/service-1/{base, overlays/dev,staging,prod}
│       └── team-b/service-2/{base, overlays/dev,staging,prod}
├── docs/
│   ├── onboarding.md         # how a new team/service joins the GitOps platform
│   └── runbooks/             # operational runbooks
└── scripts/
    ├── bootstrap.sh          # kind + ArgoCD + root app
    └── cleanup.sh            # tear down
```

---

## Portfolio-ready checklist

This project is portfolio-ready (and "done" for Pass 1) when you can tick:

- [ ] Clear problem statement and architecture diagram in the README
- [ ] Reproducible from scratch: `./scripts/bootstrap.sh` builds it on a clean machine
- [ ] One **app-of-apps** root Application bootstraps platform + apps
- [ ] **ApplicationSets** generate the per-environment Applications (no copy-paste)
- [ ] dev & staging **auto-sync and self-heal**; prod is a **manual gate**
- [ ] You promoted a change dev → staging → prod **by pull request**
- [ ] You rolled back by **reverting a Git commit** and watched ArgoCD converge
- [ ] You deleted a live resource and watched ArgoCD **self-heal** it
- [ ] At least one [ADR](./architecture/decisions/) explaining a key decision
- [ ] An [onboarding guide](./docs/onboarding.md) for adding a new service
- [ ] Cleanup works and leaves nothing running

Pass 2 adds: ESO-managed secrets, a signed-image Kyverno policy, CI-driven digest
promotion, and sync/drift notifications.

---

## Architecture decisions

The choices behind this platform are documented as ADRs you can read and challenge:

- [ADR-003 — Why ArgoCD over Flux](./architecture/decisions/ADR-003-why-argocd.md)
- [ADR-012 — Why a folder strategy over a branch strategy for environments](./architecture/decisions/ADR-012-folder-over-branch-strategy.md)
- [ADR-013 — Why app-of-apps + ApplicationSets](./architecture/decisions/ADR-013-app-of-apps-and-applicationsets.md)
- [ADR-014 — Why External Secrets Operator over committing secrets](./architecture/decisions/ADR-014-secrets-strategy.md)

---

_Previous:_ [08 · GitOps](../../08-gitops/)
· _Next:_ [10 · Kubernetes Advanced](../../10-kubernetes-advanced/)
