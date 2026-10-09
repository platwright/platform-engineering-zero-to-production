# Build Guide — Container Platform Foundation

> The staged walkthrough. **Pass 1** builds the foundation on a free local `kind`
> cluster using what you learned in Phases 2–3. **Pass 2** upgrades each piece to
> production as later phases teach it. Do Pass 1 in one sitting; it takes ~1–2 hours.

**Type:** Build project
**Deliverable:** A reproducible, multi-team cluster foundation with verified
isolation, least-privilege access, resource guardrails, and a hardened workload.

## Prerequisites

- Docker and `kind` and `kubectl` installed
  ([environment setup](../../00-orientation/environment-setup.md)).
- You're in this project directory:
  `04-platform-project-01/container-platform-foundation/`.

---

## Pass 1 — Build it now (local, free)

### Stage 0 — Create the cluster

The fast path runs everything for you:

```bash
./scripts/bootstrap.sh
```

Prefer to go step by step? Create the cluster yourself and continue:

```bash
kind create cluster --name platform-foundation
kubectl cluster-info --context kind-platform-foundation
```

### Stage 1 — Namespaces and Pod Security Admission

```bash
kubectl apply -f kubernetes/platform/00-namespaces.yaml
kubectl get ns --show-labels
```

Notice the `pod-security.kubernetes.io/enforce=restricted` label on `team-a` and
`team-b`. That's a **built-in guardrail**: the API server will reject any pod in
these namespaces that isn't hardened — before you install any policy engine.

### Stage 2 — Resource guardrails (LimitRange + ResourceQuota)

```bash
kubectl apply -f kubernetes/platform/10-limitranges.yaml
kubectl apply -f kubernetes/platform/20-resourcequotas.yaml

kubectl -n team-a describe limitrange default-limits
kubectl -n team-a describe resourcequota team-quota
```

The LimitRange gives containers sane default requests/limits; the ResourceQuota caps
the namespace's total budget so one team can't starve the cluster.

### Stage 3 — Least-privilege RBAC

```bash
kubectl apply -f kubernetes/platform/30-rbac-team-a.yaml
kubectl apply -f kubernetes/platform/31-rbac-team-b.yaml
```

Now **prove** least privilege with impersonation (`--as` / `--as-group`):

```bash
# The CI deployer can ship to its own namespace...
kubectl auth can-i create deployments -n team-a \
  --as=system:serviceaccount:team-a:ci-deployer        # -> yes

# ...but cannot delete namespaces or read secrets broadly...
kubectl auth can-i delete namespaces \
  --as=system:serviceaccount:team-a:ci-deployer        # -> no
kubectl auth can-i list secrets -n team-a \
  --as=system:serviceaccount:team-a:ci-deployer        # -> no

# ...and a team-a member cannot touch team-b.
kubectl auth can-i get pods -n team-b \
  --as-group=team-a --as=alice                         # -> no
```

### Stage 4 — Deploy the hardened golden-path workload

```bash
kubectl apply -f kubernetes/apps/team-a-hello.yaml
kubectl -n team-a rollout status deployment/hello

# Confirm it runs non-root with a read-only root filesystem
kubectl -n team-a get pod -l app=hello -o jsonpath='{.items[0].spec.securityContext}{"\n"}'
kubectl -n team-a exec deploy/hello -- id            # uid=101, not root
kubectl -n team-a exec deploy/hello -- touch /blocked 2>&1 || echo "read-only root FS: write denied (good)"
```

### Stage 5 — Break the guardrails on purpose

A guardrail you haven't tested is a guardrail you don't have. Confirm each one holds.

**(a) Pod Security Admission rejects an unhardened pod:**

```bash
kubectl -n team-a run rootpod --image=nginx --restart=Never
# Expected: the API server REJECTS it (violates the "restricted" standard).
```

**(b) The ResourceQuota blocks a runaway deployment:**

```bash
# Ask for far more than the namespace budget allows
kubectl -n team-a scale deployment/hello --replicas=100
kubectl -n team-a get deploy hello                    # replicas will be capped
kubectl -n team-a describe resourcequota team-quota   # see "used" vs "hard"
kubectl -n team-a get events | grep -i exceeded       # quota rejection events
kubectl -n team-a scale deployment/hello --replicas=2 # restore
```

**(c) RBAC denies a forbidden action:**

```bash
# The CI deployer trying to delete the namespace is denied
kubectl delete namespace team-a \
  --as=system:serviceaccount:team-a:ci-deployer 2>&1 || echo "denied (good)"
```

If all three held, your foundation's guardrails work. That's the deliverable.

### Stage 6 — Clean up

```bash
./scripts/cleanup.sh        # deletes the kind cluster and everything in it
```

---

## Pass 2 — Upgrade to production (as later phases teach it)

Return to each item as you complete the relevant phase. The
[`terraform/`](./terraform/), [`helm/`](./helm/), and
[`.github/workflows/`](./.github/workflows/) folders hold starting points.

1. **Provision the cluster as code** — replace `kind` with a GKE cluster, VPC, node
   pools, and remote state, all in Terraform.
   → [Phase 4 · Infrastructure as Code](../../05-infrastructure-as-code/)
2. **A build→scan→sign→push pipeline** that blocks on critical CVEs and signs images
   with Cosign (keyless via OIDC).
   → [Phase 5 · CI/CD](../../06-cicd-for-platform-teams/)
3. **Make hardening structural** — enforce non-root/read-only/signed-images with
   Kyverno across all namespaces, not just by Pod Security Admission.
   → [Phase 13 · Security and Policy](../../13-security-and-policy-engineering/)
4. **External secrets** — sync from GCP Secret Manager with the External Secrets
   Operator; nothing secret in Git.
   → [Phase 13 · Security and Policy](../../13-security-and-policy-engineering/)
5. **Default-deny networking** — Cilium CNI with NetworkPolicies that deny by default
   and allow selectively.
   → [Phase 14 · Kubernetes Networking](../../14-kubernetes-networking/)
6. **Observe it** — a metrics/logs/traces baseline and SLOs for the foundation.
   → [Phase 9 · Observability](../../11-observability-engineering/)

As you finish each, update the [portfolio-ready checklist](./README.md#portfolio-ready-checklist).

---

## Reflection

- Which guardrail would stop the most real-world incidents: PSA, quotas, or RBAC?
- The CI deployer is intentionally narrow. What's the risk of a broad "deploy with
  cluster-admin" service account that many teams fall into?
- Pass 1 enforces hardening by Pod Security Admission. Why is Kyverno (Pass 2) still
  worth adding — what can it check that PSA cannot (hint: image signatures, required
  cost labels, allowed registries)?
