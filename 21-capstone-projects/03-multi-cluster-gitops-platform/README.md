# Capstone 3 — Multi-Cluster GitOps Platform

> Build a multi-cluster platform serving three environments across two regions, driven
> by GitOps, with full promotion automation and tested disaster recovery. This takes
> Project 2's single-cluster GitOps to a **fleet** — a management cluster governing
> workload clusters, cross-region DR, and promotion gated end to end.

**Type:** Capstone (portfolio build)
**Estimated effort:** ~50–70 hours
**Builds on:** [Project 2](../../09-platform-project-02/),
[Project 3](../../12-platform-project-03/), [Phase 7 · GitOps](../../08-gitops/),
[Phase 13 · Platform SRE](../../17-platform-sre/), and
[Phase 15 · Multi-Cluster](../../19-multi-cluster-and-multi-cloud/).

## Goal

A platform that spans multiple clusters and regions, where a single management cluster
runs the control plane (ArgoCD, Backstage, Vault), workload clusters are created and
upgraded declaratively, changes promote dev → staging → prod through evaluation gates,
and a prod region can fail over to a DR replica. This is the architecture real
organizations run when one cluster isn't enough — for isolation, regional HA, or
regulatory reasons.

## Suggested architecture

```text
   Management cluster (us-central1)
     ├─ ArgoCD (manages ALL clusters via ApplicationSets)
     ├─ Backstage (the catalog/portal across the fleet)
     └─ Vault (secrets source of truth)
          │  Cluster API bootstraps + upgrades the workload clusters
          ▼
   Workload clusters:
     dev-us-central1       ← auto-sync, spot nodes
     staging-us-central1   ← auto-sync after dev passes evaluation
     prod-us-central1      ← manual gate, HA node pools
     prod-us-east1         ← DR replica, Cilium Cluster Mesh with prod-central
          │
   Global load balancer routes between the two prod regions (health-based failover)
```

## Requirements

- [ ] **Cluster API bootstraps all workload clusters** from the management cluster — [Module 19.2](../../19-multi-cluster-and-multi-cloud/02-fleet-management-with-cluster-api/)
- [ ] **ArgoCD ApplicationSets deploy to all clusters** (cluster generator) — [Module 08.3](../../08-gitops/03-argocd-applicationsets/), [Module 19.1](../../19-multi-cluster-and-multi-cloud/01-multi-cluster-architecture/)
- [ ] **Cluster Mesh**: prod clusters share service visibility — [Module 14.4](../../14-kubernetes-networking/04-cilium-and-ebpf/), [Module 19.1](../../19-multi-cluster-and-multi-cloud/01-multi-cluster-architecture/)
- [ ] **Promotion pipeline**: dev → staging → prod, each with an evaluation gate — [Module 08.4](../../08-gitops/04-multi-environment-gitops/)
- [ ] **Velero DR**: cross-region backup, tested restore — [Module 17.6](../../17-platform-sre/06-disaster-recovery-for-platform/)
- [ ] **Global load balancer** routing between prod regions — [Module 19.4](../../19-multi-cluster-and-multi-cloud/04-global-load-balancing-and-edge/)
- [ ] **Platform SLOs measured per cluster** — [Module 17.2](../../17-platform-sre/02-platform-slos/)

## How it extends Project 2

Project 2 was one cluster, one ArgoCD, folder-based environments. This capstone scales
that to a fleet:

- **A management cluster** runs the control plane; **ApplicationSets with a cluster
  generator** fan the same config out to many workload clusters (Project 2 used a Git
  directory generator; here you add the cluster dimension).
- **Cluster API** makes the clusters themselves declarative and reproducible — no
  click-ops cluster creation.
- **Cross-region DR** and a **global load balancer** add the availability story a single
  cluster can't have.
- **Per-cluster SLOs** mean you can see each region's health independently.

> Honesty note: a true multi-region cloud build has real cost. You can build and
> demonstrate most of this locally with **multiple kind clusters** (management + two
> workloads) registered in ArgoCD and a Cluster API **Docker (CAPD)** provider, then
> document the cloud deltas (GKE, cross-region, global LB). A convincing local build
> plus a clear "here's what changes in the cloud" is a legitimate capstone.

## Definition of done

Meets the [portfolio standard](../portfolio-standard.md) and the
[production readiness checklist](../production-readiness-checklist.md). Concretely:

- [ ] The management cluster creates a workload cluster declaratively (Cluster API).
- [ ] One ApplicationSet deploys an app to **every** registered cluster.
- [ ] A change promotes dev → staging → prod through gates you can demonstrate.
- [ ] You failed over prod to the DR replica and restored from a cross-region Velero
  backup.
- [ ] Each cluster reports its own platform SLOs.

## Deliverables

- A **GitHub repository** with the management-cluster config, Cluster API manifests,
  ApplicationSets, and DR runbooks.
- An **architecture diagram** of the fleet (management + workload clusters, regions,
  Cluster Mesh, global LB).
- A **tested DR runbook** for regional failover.
- **Per-cluster SLO dashboards**.
- **ADRs** for the fleet decisions (management-cluster pattern, Cluster API provider,
  folder-vs-cluster ApplicationSet strategy, active-passive vs active-active).

## Where to start

1. Stand up a **management kind cluster** with ArgoCD + two workload kind clusters;
   register all three in ArgoCD.
2. Convert your Project 2 ApplicationSets to a **cluster generator** so the same app
   deploys to all workload clusters.
3. Add **Cluster API (CAPD)** to create a workload cluster declaratively from the
   management cluster.
4. Add **cross-cluster DR** (Velero) and a **promotion pipeline** with gates.
5. Document the **cloud deltas** (GKE via CAPG, cross-region, global LB, Cluster Mesh)
   and **test the DR runbook**.

---

_Back to:_ [Capstones overview](../README.md)
· _Previous:_ [02 — Full IDP with Backstage](../02-full-idp-with-backstage/)
· _Next:_ [04 — Production Platform Reference Architecture →](../04-production-platform-reference-architecture/)
