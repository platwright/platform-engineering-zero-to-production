# ADR-001 — Why GKE over self-managed Kubernetes

## Status

Accepted
Date: 2026-10-09

## Context

The platform foundation needs a Kubernetes control plane and worker nodes. We can
either run Kubernetes ourselves (kubeadm, kops, or bare clusters on VMs) or use a
managed offering. The platform team is small and its differentiating value is the
**golden paths and guardrails on top of** Kubernetes — not operating etcd,
rotating control-plane certificates, or patching the API server at 3am.

Constraints: small team, GCP as the primary cloud, a preference to spend scarce
engineering effort on developer-facing capabilities rather than undifferentiated
cluster plumbing.

## Decision

We will use **Google Kubernetes Engine (GKE)** as the cluster platform for this
foundation and the course's cloud labs.

## Consequences

- **Easier:** control-plane availability, upgrades, node auto-repair, and scaling
  are managed by the provider. We inherit a tested, SLA-backed control plane.
- **Easier:** tight integration with GCP IAM, networking, Artifact Registry, and
  Secret Manager — which the later phases rely on.
- **Harder / trade-offs:** some loss of control over control-plane internals; GKE
  version availability gates how fast we adopt new Kubernetes releases; a cloud
  bill (mitigated with budgets, small nodes, and spot).
- **Portability:** we keep cloud-specific config isolated so the *concepts* remain
  valid on EKS/AKS or self-managed clusters.

## Alternatives considered

- **Self-managed (kubeadm/kops on VMs)** — maximum control, but we'd own
  control-plane operations, upgrades, and HA. The operational cost dwarfs the
  benefit for a team whose value is above the cluster.
- **Other managed Kubernetes (EKS/AKS)** — equally valid; we standardize on GKE
  because the course uses GCP as its primary cloud. The patterns transfer.
- **Local only (kind/k3d)** — perfect for learning (we use it for Pass 1), but not
  a production foundation.

## References

- [GKE documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Phase 3 · Kubernetes Fundamentals](../../../../03-kubernetes-fundamentals/)
