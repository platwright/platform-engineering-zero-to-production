# Runbook — Roll back a bad change (GitOps)

> **When to use:** a change reached an environment and caused a problem (a bad image,
> a broken config), and you need to get back to the last known-good state.

## Principle

In GitOps you do **not** hotfix the cluster with `kubectl`. The cluster converges to
Git, so a manual fix is transient and will be reverted by the next sync. **Roll back
by changing Git**, then let ArgoCD reconcile.

## Fast path — revert the commit

```bash
cd /path/to/your/gitops-config

# Find the offending commit
git log --oneline -n 10

# Revert it (creates a new commit that undoes it — keeps history honest)
git revert --no-edit <bad-commit-sha>
git push
```

ArgoCD syncs the affected environments back to the previous state:

```bash
kubectl -n argocd get applications
argocd app get <app>          # confirm Synced + Healthy again
```

For **production**, the revert lands in Git but prod won't apply until you sync the
gate:

```bash
argocd app diff <team>-<svc>-prod
argocd app sync <team>-<svc>-prod
```

## Alternative — ArgoCD history rollback (temporary)

ArgoCD can roll an Application to a previous *synced* revision. Use this only as an
emergency stop; it makes the live state differ from Git until you also fix Git:

```bash
argocd app history <app>
argocd app rollback <app> <history-id>
```

Then **still** revert the bad commit in Git so Git and cluster agree again
(otherwise self-heal/next sync will reapply the bad state).

## Verify

- `argocd app get <app>` shows `Synced` + `Healthy`.
- The workload is back to the known-good image/replicas.
- Git `HEAD` reflects the rolled-back state (no lingering drift).

## Prevent

- Promote through dev → staging before prod; don't skip environments.
- Keep prod behind the manual sync gate and PR review.
- In Pass 2, require signed images and run policy checks before sync so a bad image
  is rejected at admission, not after rollout.

## Escalation

If a revert doesn't converge, treat it as an "Application not syncing" incident — see
[argocd-app-out-of-sync.md](./argocd-app-out-of-sync.md).
