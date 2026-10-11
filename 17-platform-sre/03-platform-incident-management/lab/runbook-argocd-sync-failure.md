<!-- markdownlint-disable MD033 -->
# Runbook — Argo CD sync failing

> A short, tested procedure for "teams cannot deploy — Argo CD is not syncing". Linked
> from the `GitOpsSyncLatency` and `ArgoCDApiAvailability` alerts (Module 17.2). Living
> document: after every use, improve it.

**Owner:** platform-team · **Last tested:** `<date>` · **Severity if org-wide:** P1

## Symptom

- Burn-rate alert `GitOpsSyncLatency` or `ArgoCDApiAvailability` firing, or
- Applications stuck `OutOfSync` / `Unknown` / `ComparisonError`, or
- Teams report "my deploy isn't rolling out".

## Confirm

```bash
kubectl -n argocd get applications -o wide
# many apps Unknown/ComparisonError at once → platform-wide, not one app's config
```

## Diagnose (fast, then mitigate — do not deep-dive while teams are down)

```bash
# is a core component down?
kubectl -n argocd get deploy,sts
kubectl -n argocd get pods -o wide | grep -v Running

# repo-server (renders manifests) — the usual suspect for "all syncs fail"
kubectl -n argocd logs deploy/argocd-repo-server --tail=50

# application-controller (performs the sync)
kubectl -n argocd logs statefulset/argocd-application-controller --tail=50

# recent cluster events
kubectl -n argocd get events --sort-by=.lastTimestamp | tail -n 20
```

Decision tree:

- **repo-server is 0/0 or crashlooping** → restore it (mitigation A).
- **application-controller down** → restart it (mitigation B).
- **a single app is broken** (bad path/revision pushed to Git) → revert the Git commit
  (mitigation C); this is not platform-wide, lower the severity.

## Mitigate (stop the bleeding)

```bash
# A) repo-server offline → scale/restart it
kubectl -n argocd scale deploy/argocd-repo-server --replicas=1
kubectl -n argocd rollout restart deploy/argocd-repo-server

# B) application-controller stuck → restart it
kubectl -n argocd rollout restart statefulset/argocd-application-controller

# C) a bad config was pushed → revert in Git; GitOps rolls it back
#    git revert <bad-sha> && git push   (Argo CD re-syncs to the good state)

# force the apps to retry immediately
kubectl -n argocd annotate application --all argocd.argoproj.io/refresh=hard --overwrite
```

## Verify

```bash
kubectl -n argocd get applications -o wide   # back to Synced/Healthy
# the burn-rate alert should clear within a few minutes
```

## Escalate

- Not recovered within **15 minutes** → raise severity, page the platform lead, and
  consider rolling back the last platform change.

## After the incident

- Write the postmortem ([`postmortem-template.md`](./postmortem-template.md)).
- Update this runbook with anything that was wrong or missing.
