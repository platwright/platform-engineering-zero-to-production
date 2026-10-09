# Runbook — Team hit its ResourceQuota

> **When to use:** a team reports that new pods won't schedule, deployments are
> stuck, or `kubectl apply` fails with a "forbidden: exceeded quota" error.

## Symptoms

- `kubectl apply` / scale fails with: `exceeded quota: team-quota, requested ...`.
- A Deployment's desired replicas are higher than the available/ready pods.
- Events show `FailedCreate` with a quota message.

## Diagnose

```bash
NS=team-a
kubectl -n "$NS" describe resourcequota team-quota     # compare "used" vs "hard"
kubectl -n "$NS" get events --sort-by=.lastTimestamp | grep -i quota
kubectl -n "$NS" get pods --field-selector=status.phase=Pending
```

Identify whether the team is:

- **Legitimately growing** (needs a bigger budget), or
- **Leaking/oversized** (forgotten workloads, requests set far above real usage).

## Resolve

- **Right-size first.** Check actual usage vs requests
  (`kubectl top pods -n "$NS"` if metrics-server is installed). Often the fix is
  lowering inflated requests, not raising the quota.
- **Clean up** abandoned Deployments/Jobs/PVCs in the namespace.
- **Raise the quota** only when growth is real and agreed. Edit the namespace's
  `ResourceQuota` and re-apply, and record the new budget in the team's entry.

```bash
kubectl -n "$NS" edit resourcequota team-quota   # adjust requests/limits/pods
```

## Prevent

- Review quotas vs actual usage periodically (a FinOps habit — see
  [Phase 14 · FinOps](../../../../18-finops-and-cost-engineering/)).
- Encourage realistic resource requests in the golden-path template.
- Alert when a namespace crosses ~80% of its quota so teams aren't surprised.

## Escalation

If raising the quota would exceed cluster capacity, this is a **capacity** issue,
not just a quota one — involve whoever owns node provisioning (autoscaling /
Karpenter, a stretch goal here and a topic in
[Phase 13 · Platform SRE](../../../../17-platform-sre/)).
