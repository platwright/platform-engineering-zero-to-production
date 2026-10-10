# config-repo — the single source of truth

> This directory is a **template for your GitOps config repository**. You push its
> contents to your own Git host (a free GitHub repo works), replace the
> `__CONFIG_REPO_URL__` placeholder with that repo's URL, and point ArgoCD at it. From
> then on, the cluster's desired state lives here, and every change is a commit.

## Layout

```text
config-repo/
├── argocd/                       # ArgoCD resources (the app-of-apps children)
│   ├── platform.yaml             # Application → syncs platform/ (auto)
│   ├── apps-nonprod-appset.yaml  # ApplicationSet → dev + staging Applications (auto)
│   └── apps-prod-appset.yaml     # ApplicationSet → prod Applications (manual gate)
├── platform/                     # cluster-wide config, synced by the platform App
│   ├── namespaces.yaml           # 6 namespaces (team × env) with Pod Security
│   ├── resourcequotas.yaml       # per-namespace budgets
│   └── pass2/                    # NOT synced in Pass 1 (Kyverno/ESO — see its README)
└── apps/
    ├── team-a/service-1/{base, overlays/dev,staging,prod}
    └── team-b/service-2/{base, overlays/dev,staging,prod}
```

## How the pieces connect

```text
bootstrap/root-app.yaml  (applied once)
   └─ syncs  argocd/
        ├─ platform.yaml            → syncs platform/        (namespaces, quotas)
        ├─ apps-nonprod-appset.yaml → 1 Application per dev/staging overlay (auto-sync)
        └─ apps-prod-appset.yaml    → 1 Application per prod overlay (manual gate)
```

Each app's environments are **Kustomize overlays** (`overlays/dev`,
`overlays/staging`, `overlays/prod`) over a shared `base/`. The overlay sets the
namespace, replica count, and image tag — nothing else is duplicated.

## Using it

1. Copy `config-repo/`'s contents into a fresh Git repo on your host.
2. Replace the placeholder everywhere with your repo's URL:

   ```bash
   export CONFIG_REPO_URL="https://github.com/<you>/gitops-config.git"
   grep -rl __CONFIG_REPO_URL__ . | xargs sed -i "s|__CONFIG_REPO_URL__|$CONFIG_REPO_URL|g"
   git add -A && git commit -m "init gitops config" && git push
   ```

3. Bootstrap the cluster (from the project root):
   `export CONFIG_REPO_URL=...; ./scripts/bootstrap.sh`.

Full walkthrough: [../build-guide.md](../build-guide.md).

> **Add a service** by adding a folder under `apps/<team>/<service>/overlays/*` — the
> ApplicationSets generate its Applications automatically. See
> [../docs/onboarding.md](../docs/onboarding.md).
