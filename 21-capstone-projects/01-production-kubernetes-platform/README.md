# Capstone 1 — Production Kubernetes Platform

> Build a complete, multi-team, production-grade Kubernetes platform from scratch —
> the cluster foundation plus every structural capability a real organization needs:
> secure by default, delivered by GitOps, fully observable, cost-attributed, and
> recoverable. This is Projects 1–3 taken from "local demo" to "a platform teams could
> actually run on."

**Type:** Capstone (portfolio build)
**Estimated effort:** ~40–60 hours
**Builds on:** [Project 1](../../04-platform-project-01/),
[Project 2](../../09-platform-project-02/), [Project 3](../../12-platform-project-03/),
and Phases 2–14.

## Goal

A production-grade Kubernetes platform that three teams could deploy onto safely,
where every structural concern — security, delivery, observability, cost, recovery —
is built in rather than bolted on. You should be able to hand a new team an onboarding
guide and have them ship a service without ever touching the platform's internals.

## Requirements

Work toward this checklist. Each item links to where the course taught it, so you're
assembling known pieces, not inventing.

- [ ] **GKE cluster provisioned with Terraform** — [Phase 4](../../05-infrastructure-as-code/)
- [ ] **Cilium as CNI** (replacing kube-proxy) — [Module 14.4](../../14-kubernetes-networking/04-cilium-and-ebpf/)
- [ ] **Multi-namespace structure with RBAC per team** — [Project 1](../../04-platform-project-01/), [Module 03.6](../../03-kubernetes-fundamentals/06-rbac/)
- [ ] **LimitRanges and ResourceQuotas per namespace** — [Module 03.7](../../03-kubernetes-fundamentals/07-resource-management/)
- [ ] **Karpenter for node autoscaling** (spot-first) — [Module 17.4](../../17-platform-sre/04-platform-capacity-planning/), [Module 18.4](../../18-finops-and-cost-engineering/04-cost-optimization-patterns/)
- [ ] **Kyverno** — image signing, non-root, resource limits, cost labels — [Module 13.3](../../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/)
- [ ] **External Secrets Operator + GCP Secret Manager** — [Module 13.4](../../13-security-and-policy-engineering/04-secret-management/)
- [ ] **Kubernetes Gateway API** with the GKE Gateway controller — [Module 14.5](../../14-kubernetes-networking/05-kubernetes-gateway-api/)
- [ ] **Network policies**: default-deny all, selective allow — [Module 14.3](../../14-kubernetes-networking/03-network-policies/)
- [ ] **Falco for runtime security** — [Module 13.7](../../13-security-and-policy-engineering/07-runtime-security/)
- [ ] **All provisioning via GitOps** (ArgoCD) — [Project 2](../../09-platform-project-02/)
- [ ] **Full LGTM observability stack** — [Project 3](../../12-platform-project-03/)
- [ ] **SLOs for all platform services** — [Module 11.7](../../11-observability-engineering/07-slos-and-error-budgets/), [Module 17.2](../../17-platform-sre/02-platform-slos/)
- [ ] **Backstage Software Catalog** — [Module 15.3](../../15-developer-experience-and-idp/03-backstage-software-catalog/)
- [ ] **CI pipeline template for all teams** — [Module 06.4](../../06-cicd-for-platform-teams/04-pipeline-templates-as-product/)
- [ ] **Cluster backup with Velero** — [Module 17.6](../../17-platform-sre/06-disaster-recovery-for-platform/)
- [ ] **Disaster recovery runbook, tested** — [Module 17.6](../../17-platform-sre/06-disaster-recovery-for-platform/)

## Suggested architecture

```text
   GitHub (app repos + config repo)
        │  CI: build → scan → sign → push
        ▼
   GHCR / Artifact Registry  ──(signed, by digest)──┐
                                                     │
   GKE cluster (Terraform)                           │
     ├─ Cilium CNI (+ Gateway API ingress)           │
     ├─ Namespaces: platform-system, team-a, team-b  │
     │    RBAC · LimitRange · ResourceQuota per team  │
     ├─ Kyverno  ◄── verify signatures, enforce ──────┘
     │             non-root / limits / cost labels
     ├─ External Secrets Operator → GCP Secret Manager
     ├─ Falco (runtime security)
     ├─ Karpenter (spot-first node autoscaling)
     └─ LGTM stack (OTel → Prometheus/Loki/Tempo/Grafana) + SLOs
        │
   ArgoCD reconciles ALL of the above from the config repo (GitOps)
   Velero backs it up; the DR runbook restores it
   Backstage catalogs every service
```

Reuse your Project 1 Terraform/manifests, Project 2 GitOps config, and Project 3
observability stack as the starting point — the capstone is about *integrating and
hardening* them into one coherent, GitOps-delivered platform.

## Definition of done

Meets the [portfolio standard](../portfolio-standard.md) and answers the
[production readiness checklist](../production-readiness-checklist.md). Concretely:

- [ ] `terraform apply` + an ArgoCD bootstrap brings the whole platform up from scratch.
- [ ] A non-compliant workload (root, unsigned, unlabeled) is **rejected** by policy.
- [ ] A new team can onboard and deploy a service using only the onboarding guide.
- [ ] You can trace a change from Git commit to running pod, and see its telemetry.
- [ ] You triggered the DR runbook and restored from a Velero backup.
- [ ] Every platform service has an SLO and a burn-rate alert linked to a runbook.

## Deliverables

- A **GitHub repository** with full IaC, GitOps config, and documentation.
- An **architecture diagram** showing all components (a real one — see the portfolio
  standard).
- A **Platform SLO dashboard** (Grafana).
- A **DR runbook** (tested).
- An **onboarding guide** for new development teams.
- **ADRs** for the significant choices (many you can adapt from Projects 1–3:
  [why GKE](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-001-why-gke.md),
  [why Cilium](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md),
  [why Kyverno](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-004-why-kyverno.md),
  [why ArgoCD](../../09-platform-project-02/gitops-platform/architecture/decisions/ADR-003-why-argocd.md), …).

## Where to start

1. Start from your **Project 1** foundation (Terraform cluster, namespaces, RBAC,
   quotas, hardened workloads).
2. Put it all under **GitOps** (Project 2) so ArgoCD provisions it — including the
   platform add-ons (Cilium, Kyverno, ESO, Falco, Karpenter).
3. Layer in **observability** (Project 3) and define **SLOs** for each platform service.
4. Add the **catalog** (Backstage) and a shared **CI template**.
5. Prove **recovery** (Velero + DR runbook) and **write everything down** to the
   portfolio standard.

> Scope honestly. A platform that does fewer things but is reproducible, observable,
> secured, and documented beats one that claims everything and runs nowhere. Unchecked
> requirements become documented "known limitations," not hidden gaps.

---

_Back to:_ [Capstones overview](../README.md)
· _Next capstone:_ [02 — Full IDP with Backstage →](../02-full-idp-with-backstage/)
