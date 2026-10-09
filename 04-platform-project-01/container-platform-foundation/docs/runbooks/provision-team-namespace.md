# Runbook — Provision a new team namespace

> **When to use:** a new team needs a namespace on the foundation, or an existing
> team needs a second environment namespace.

## Summary

Create an isolated, guard-railed namespace: Pod Security enforcement, RBAC,
LimitRange, and ResourceQuota.

## Steps

See the full procedure in [onboarding.md](../onboarding.md). In short:

1. Create the namespace with Pod Security labels (`enforce=restricted`).
2. Apply a LimitRange and a ResourceQuota (sized to the agreed budget).
3. Apply RBAC: a `team-owner` Role bound to the team's group, plus a narrow
   `ci-deployer` ServiceAccount and Role.
4. Verify with `kubectl auth can-i` (positive and negative checks).

## Verification

```bash
kubectl get ns team-c --show-labels
kubectl -n team-c get limitrange,resourcequota,role,rolebinding,serviceaccount
kubectl auth can-i create deployments -n team-c \
  --as=system:serviceaccount:team-c:ci-deployer     # expect: yes
kubectl auth can-i delete namespaces \
  --as=system:serviceaccount:team-c:ci-deployer     # expect: no
```

## Rollback

```bash
kubectl delete namespace team-c   # removes the namespace and everything in it
```

## Escalation

If PSA rejects the team's legitimate workload, do **not** downgrade the namespace to
`baseline` as a reflex. First confirm the workload can be hardened (it almost always
can). Downgrade only with a documented, time-boxed exception and a plan to return to
`restricted`.
