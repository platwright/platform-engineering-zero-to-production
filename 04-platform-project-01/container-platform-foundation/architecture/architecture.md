# Architecture — Container Platform Foundation

This document describes the architecture of the Container Platform Foundation: what
it is made of, how the pieces fit, and the reasoning behind the design. Decisions
with meaningful trade-offs are captured as [ADRs](./decisions/).

## Problem statement

Three application teams need to deploy services to Kubernetes safely. Without a
foundation, each team would re-solve isolation, access control, resource limits,
and security — inconsistently, and usually insecurely. The platform team's job is
to provide a **foundation they build on**: safe defaults, clear boundaries, and
self-service within guardrails.

## Design goals

- **Isolation.** One team cannot see, modify, or starve another team's workloads.
- **Least privilege.** Every identity (humans and CI) gets the minimum access it
  needs — nothing more.
- **Guardrails, not gates.** Safety is enforced automatically (quotas, policy), not
  by a human approving every change.
- **Secure by default.** Workloads run non-root, read-only, with dropped
  capabilities and no baked-in secrets.
- **Reproducible.** The whole foundation can be rebuilt from code on a clean machine.

## High-level architecture

```text
                         ┌──────────────────────────────┐
   Developer / CI ─────► │  Kubernetes API server (RBAC) │
                         └───────────────┬──────────────┘
                                         │
       ┌─────────────────────────────────┼─────────────────────────────────┐
       ▼                                 ▼                                 ▼
 ┌───────────────┐              ┌───────────────┐                 ┌───────────────┐
 │ platform-     │              │ team-a        │                 │ team-b        │
 │ system        │              │ (namespace)   │                 │ (namespace)   │
 │ (namespace)   │              │  RBAC: owner  │                 │  RBAC: owner  │
 │  operators,   │              │  Quota+Limits │                 │  Quota+Limits │
 │  platform svc │              │  CI deployer  │                 │  CI deployer  │
 └───────────────┘              └───────────────┘                 └───────────────┘
       │                                 │                                 │
       └─────────────────────────────────┴─────────────────────────────────┘
                                         │
                 enforced across all namespaces (Pass 2):
                 Kyverno policy · default-deny NetworkPolicy · signed-image check
```

## Component inventory

| Component | Role | Pass | Introduced in |
|-----------|------|:----:|---------------|
| GKE cluster | Managed Kubernetes control plane + nodes | 2 | [Phase 4](../../../05-infrastructure-as-code/) |
| VPC + subnets | Network for the cluster | 2 | [Phase 4](../../../05-infrastructure-as-code/) |
| Terraform + GCS backend | Provisions and tracks all infrastructure | 2 | [Phase 4](../../../05-infrastructure-as-code/) |
| Namespaces | Isolation boundary per team | **1** | [Phase 3](../../../03-kubernetes-fundamentals/) |
| RBAC (Roles/Bindings) | Least-privilege access per namespace | **1** | [Phase 3 · RBAC](../../../03-kubernetes-fundamentals/06-rbac/) |
| LimitRange | Default + max container resources per namespace | **1** | [Phase 3 · Resources](../../../03-kubernetes-fundamentals/07-resource-management/) |
| ResourceQuota | Total resource budget per namespace | **1** | [Phase 3 · Resources](../../../03-kubernetes-fundamentals/07-resource-management/) |
| Hardened workload | Non-root, read-only, dropped caps sample app | **1** | [Phase 2/3](../../../02-containerization/) |
| CI pipeline | build → scan → sign → push (blocks on CVEs) | 2 | [Phase 5](../../../06-cicd-for-platform-teams/) |
| Kyverno | Enforces non-root/read-only/signed images | 2 | [Phase 13](../../../13-security-and-policy-engineering/) |
| External Secrets Operator | Syncs secrets from Secret Manager | 2 | [Phase 13](../../../13-security-and-policy-engineering/) |
| Cilium | CNI + eBPF + network policy | 2 | [Phase 14](../../../14-kubernetes-networking/) |

## Namespace & tenancy model

- `platform-system` — platform-owned components (operators, controllers, shared
  services). Developers have **no** write access here.
- `team-a`, `team-b` — one namespace per stream-aligned team. Each team owns its
  namespace: deploy, scale, read logs — but cannot touch cluster-scoped resources or
  other namespaces.

Tenancy here is **soft multi-tenancy** (namespace isolation + RBAC + quotas +
network policy), appropriate for teams within one organization. Hard multi-tenancy
(hostile tenants) would need stronger isolation (separate clusters or sandboxed
runtimes) — out of scope and noted as a limitation.

## Access model (RBAC)

| Subject | Scope | Can | Cannot |
|---------|-------|-----|--------|
| Team member | own namespace | manage Deployments/Services/Pods/ConfigMaps, read logs | touch other namespaces or cluster-scoped resources |
| CI deployer (ServiceAccount) | own namespace | create/update/patch Deployments only | delete namespaces, read Secrets broadly, escalate |
| Platform admin | cluster-wide | manage the foundation | — (audited) |

The CI deployer is deliberately **narrow**: it can ship, but it can't nuke the
namespace or read every secret. Verified with `kubectl auth can-i ... --as`.

## Security posture

- **Workloads:** `runAsNonRoot: true`, `readOnlyRootFilesystem: true`,
  `allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`, a seccomp
  `RuntimeDefault` profile. Enforced by hand in Pass 1, by Kyverno in Pass 2.
- **Images:** built, scanned (Trivy), and signed (Cosign) in CI; promotion by
  immutable digest; deployment blocked on critical CVEs (Pass 2).
- **Secrets:** never in Git or images — synced from GCP Secret Manager via ESO
  (Pass 2). In Pass 1 we avoid secrets entirely in the sample app.
- **Network:** default-deny NetworkPolicy with selective allows (Pass 2, Cilium).

## Known limitations

- Pass 1 enforces pod hardening by convention (the manifests), not policy — a team
  could deploy an unhardened pod until Kyverno (Pass 2) makes it structural.
- Soft multi-tenancy only; not suitable for hostile/untrusted tenants.
- No observability stack yet (Phase 9); no autoscaling of nodes yet (stretch goal).
- Single region, single cluster. Multi-cluster/DR is [Phase 15](../../../19-multi-cluster-and-multi-cloud/).

## Production considerations

- Provision everything via Terraform with remote, locked state — never `kubectl
  apply` production infra by hand (Pass 2).
- Make hardening **structural** with admission policy so "forgot to set
  `runAsNonRoot`" cannot reach the cluster.
- Give each team an escape hatch request path for legitimate deviations, rather than
  forcing every case through the platform team.
- Budget for ongoing operation: upgrades, quota reviews, and onboarding are
  recurring work, not one-time tasks.

## Decisions

See the [ADRs](./decisions/):

- [ADR-001 — Why GKE over self-managed Kubernetes](./decisions/ADR-001-why-gke.md)
- [ADR-002 — Why Cilium as the CNI](./decisions/ADR-002-why-cilium.md)
- [ADR-004 — Why Kyverno for policy](./decisions/ADR-004-why-kyverno.md)
- [ADR-005 — Why External Secrets Operator](./decisions/ADR-005-why-external-secrets-operator.md)
