# ADR-002 — Why Cilium as the CNI

## Status

Accepted
Date: 2026-10-09

## Context

Kubernetes needs a Container Network Interface (CNI) plugin to give pods
connectivity and to enforce network policy. The foundation must support
**default-deny networking** (a security baseline) and, ideally, good network
observability so the platform team can see and debug traffic between workloads.

Constraints: we want L3–L7 policy, strong performance at scale, and visibility into
pod-to-pod traffic without bolting on a separate tool.

## Decision

We will use **Cilium** (eBPF-based) as the CNI, with Hubble for network
observability.

## Consequences

- **Easier:** eBPF dataplane offers high performance and can replace kube-proxy;
  NetworkPolicy (including L7-aware policy) and identity-based security are
  first-class; Hubble gives flow visibility out of the box.
- **Easier:** a clean path to default-deny with selective allows, which is our
  security baseline.
- **Harder / trade-offs:** eBPF and Cilium add conceptual surface area (the team
  must learn it); requires a compatible kernel; on GKE, using Cilium means GKE
  Dataplane V2 or a self-installed Cilium, which constrains some cluster options.
- Networking is deferred to [Phase 14](../../../../14-kubernetes-networking/); in
  Pass 1 we rely on the local cluster's default CNI and enforce isolation with
  namespaces + RBAC + quotas.

## Alternatives considered

- **Calico** — mature, widely used, good policy support. A strong alternative; we
  choose Cilium for its eBPF dataplane and integrated Hubble observability.
- **Cloud provider default CNI** — simplest, but weaker policy/observability story
  and less portable learning.

## References

- [Cilium documentation](https://docs.cilium.io/)
- [Phase 14 · Kubernetes Networking](../../../../14-kubernetes-networking/)
