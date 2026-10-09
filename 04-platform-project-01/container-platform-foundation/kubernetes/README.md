# Kubernetes manifests — Container Platform Foundation

These are the **Pass 1** manifests: everything you can build today on a local
`kind` cluster using what you learned in [Phase 3](../../../03-kubernetes-fundamentals/).

## Layout

```text
kubernetes/
├── platform/           # the foundation (apply first)
│   ├── 00-namespaces.yaml      # 3 namespaces + Pod Security Admission (restricted)
│   ├── 10-limitranges.yaml     # default/max container resources per namespace
│   ├── 20-resourcequotas.yaml  # total budget + object caps per namespace
│   ├── 30-rbac-team-a.yaml     # least-privilege Role + CI deployer SA (team-a)
│   └── 31-rbac-team-b.yaml     # same, for team-b
└── apps/
    └── team-a-hello.yaml       # a hardened, non-root, read-only sample workload
```

## Apply

```bash
# From the project root
kubectl apply -f kubernetes/platform/
kubectl apply -f kubernetes/apps/team-a-hello.yaml
```

Or just run [`../scripts/bootstrap.sh`](../scripts/bootstrap.sh), which creates the
cluster and applies all of the above.

## What to notice

- **Pod Security Admission** is set to `restricted` on the team namespaces, so an
  unhardened pod is rejected at admission — a structural guardrail you get *before*
  Kyverno (Phase 13). Try applying a pod without a security context and watch it be
  denied (see [build-guide.md](../build-guide.md)).
- The sample workload runs **non-root**, with a **read-only root filesystem** and
  **all capabilities dropped**; the paths nginx needs to write are supplied by
  `emptyDir` volumes.
- The **CI deployer** ServiceAccount can ship Deployments but cannot delete the
  namespace or read Secrets broadly — verify with `kubectl auth can-i`.

> This is Pass 1. In Pass 2 these same guarantees become production-grade:
> Terraform provisions the cluster, Kyverno enforces hardening cluster-wide, and
> Cilium adds default-deny networking. See the [project README](../README.md).
