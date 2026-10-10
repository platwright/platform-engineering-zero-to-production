# Runbook — ArgoCD Application stuck OutOfSync or not syncing

> **When to use:** an Application shows `OutOfSync` and isn't converging, a sync
> fails, or a change you pushed to Git isn't reflected in the cluster.

## Triage

```bash
APP=team-a-service-1-dev
kubectl -n argocd get application "$APP"
argocd app get "$APP"          # health, sync status, and conditions
argocd app diff "$APP"         # what differs between Git and the cluster
```

Identify which it is:

- **Prod and OutOfSync is EXPECTED** — prod is a manual gate. Review and
  `argocd app sync "$APP"` when ready. Not a fault.
- **A sync error** — read the message in `argocd app get` / the UI.

## Common causes and fixes

- **Manual sync required (prod).** By design. `argocd app diff` then
  `argocd app sync`.
- **Bad manifest / kustomize build error.** The repo server can't render the path.
  Reproduce locally: `kubectl kustomize apps/<team>/<svc>/overlays/<env>`. Fix the
  manifest, commit, push.
- **Pushed to the wrong branch.** The Applications track `main`
  (`targetRevision: main`). Confirm your commit is on `main`.
- **Repo not reachable / wrong URL.** Check for a leftover `__CONFIG_REPO_URL__`
  placeholder or bad credentials: `argocd repo list`.
- **Admission rejected the resource.** The namespace enforces the `restricted` Pod
  Security Standard; an unhardened pod is denied. Harden the workload (non-root,
  read-only, drop caps) — don't downgrade the namespace.
- **Drift that won't heal.** Only dev/staging have `selfHeal`. For others, sync
  explicitly or enable self-heal deliberately.

## Force a refresh

```bash
argocd app get "$APP" --refresh        # re-read Git now instead of waiting for the poll
# or hard refresh (bypass cache):
argocd app get "$APP" --hard-refresh
```

## Escalation

If the Application controller itself is unhealthy (no apps syncing cluster-wide),
check ArgoCD's own pods:

```bash
kubectl -n argocd get pods
kubectl -n argocd logs deploy/argocd-application-controller --tail=100
kubectl -n argocd logs deploy/argocd-repo-server --tail=100
```

A failed `argocd-repo-server` breaks manifest rendering for everything; a failed
`argocd-application-controller` stops reconciliation. Restart the affected
Deployment and investigate (ArgoCD is tier-1 infrastructure here).
