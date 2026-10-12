# 19 · Multi-Cluster and Multi-Cloud

> One cluster is where every platform starts and where most should stay as long
> as they can. But isolation, availability, data residency, and raw scale
> eventually force a second cluster — and then a tenth — and now you own a
> **fleet**: many API servers, many copies of policy, many desired states that
> must stay identical without anyone hand-editing them. This phase turns "we have
> several clusters" into an engineered capability: segment them on purpose, create
> and upgrade them as code, deliver one source of truth to all of them, and route
> users to the healthy one. It also tells you the honest truth about **multi-cloud**:
> it is almost always more expensive and complex than one cloud, and you should
> name the problem it solves before you pay for it.

**Phase 15 · 4 modules · ~8–12 hours**

## Why this phase matters

Everything up to here assumed a single cluster you could hold in your head. Real
platforms outgrow that. A regulator says "EU data stays in the EU." A region has a
bad morning and takes your whole product down with it. A security review decides the
payments workload needs its own blast radius, not a shared namespace. Each of those
is a *boundary* a namespace cannot draw, and each one adds a cluster.

The trap is that clusters are easy to *create* and brutal to keep *consistent*. Click
three clusters into existence from three consoles and you have three snowflakes:
different versions, different add-ons, different RBAC, and an incident on each that
nobody else's runbook covers. The discipline of this phase is the same control loop
you have used since Phase 6, lifted to the fleet:

```text
   The snowflake fleet                    The engineered fleet
   ───────────────────                    ─────────────────────
   console-created clusters        Git (one desired state for the fleet)
   hand-installed add-ons                        │
   per-cluster kubectl apply          ┌──────────▼──────────┐
   drift nobody notices               │  management cluster  │
        │                             │  CAPI · ArgoCD · RBAC │
        ▼                             └───┬───────────┬──────┘
   "which cluster is this               reconcile   reconcile
   and why is it different?"               ▼           ▼
                                      cluster A     cluster B   … (add one → it
                                      (defined,     (defined,       conforms
                                       reconciled)   reconciled)     automatically)
```

This phase gives you the four capabilities that turn a pile of clusters into a
platform:

- **Architecture.** Decide *why* and *how* you split — by environment, team, or
  region — and how clusters discover each other when they genuinely must.
- **Fleet lifecycle.** Treat a cluster as a declarative resource with **Cluster API**:
  create, upgrade, scale, and delete clusters with `kubectl apply`, reproducibly.
- **Multi-cloud, honestly.** Use **Crossplane** and Kubernetes as a portability layer
  *if* the problem demands it — and recognize the common case where multi-cloud buys
  only cost and complexity.
- **Global reach.** Put a cluster near every user, route traffic to the healthy
  region, and fail over automatically when one goes dark.

It is the direct runway to **Capstone 3 — Multi-Cluster GitOps Platform**, where you
bootstrap workload clusters from a management cluster with CAPI, fan apps out with
ApplicationSets, share service visibility across prod regions, and front it all with a
global load balancer. Learn the moves here; assemble them there.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Multi-Cluster Architecture](./01-multi-cluster-architecture/) | Segmentation strategies; the management-cluster pattern; cross-cluster service discovery (Cilium Cluster Mesh, Istio, Submariner); multi-cluster RBAC and GitOps. | Two kind clusters segmented by label, with an ApplicationSet targeting segments. |
| 2 | [Fleet Management with Cluster API](./02-fleet-management-with-cluster-api/) | Clusters as declarative resources; management vs workload clusters; providers; ClusterClass; declarative upgrades and machine pools. | A workload cluster created from a ClusterClass with the local CAPD (Docker) provider. |
| 3 | [Multi-Cloud Platform Patterns](./03-multi-cloud-platform-patterns/) | When multi-cloud adds value vs only complexity; Crossplane XRDs as the abstraction; Kubernetes as the portability layer; the real cost. | A multi-cloud decision worksheet and a Crossplane XRD/Composition sketch. |
| 4 | [Global Load Balancing and Edge](./04-global-load-balancing-and-edge/) | Active-active vs active-passive; global load balancers; latency routing; health failover; anycast; edge compute. | A global load-balancing and failover design worksheet. |

Work them in order. Module 1 frames the fleet and how you cut it; Module 2 builds the
clusters as code; Module 3 asks the hard "one cloud or many?" question; Module 4 puts
the fleet in front of real users across the planet.

## Learning objectives

By the end of this phase you will be able to:

- Choose a **cluster segmentation strategy** (per environment, per team, per region)
  from first principles, and justify when a namespace boundary is enough instead.
- Explain **cross-cluster service discovery** options (Cilium Cluster Mesh, Istio
  multi-cluster, Submariner) and design for loose coupling that avoids needing them.
- Manage a **fleet with Cluster API** — ClusterClass templates, declarative upgrades,
  auto-scaling machine pools — and run it locally on the Docker provider.
- Decide **whether multi-cloud is worth it**, and use Crossplane XRDs plus Kubernetes
  to build a portability layer when it is.
- Design **global load balancing** with latency routing, health-based failover, and a
  clear active-active vs active-passive choice backed by RTO/RPO.

## Prerequisites

- [Module 10.5 · Multi-Cluster Kubernetes](../10-kubernetes-advanced/05-multi-cluster-kubernetes/)
  — topologies, the management-cluster pattern, the ApplicationSet cluster generator,
  and multi-cluster kubeconfig. This phase goes deeper on every one of those.
- [Phase 8 · GitOps](../08-gitops/), especially
  [ApplicationSets](../08-gitops/03-argocd-applicationsets/), and
  [Project 2](../09-platform-project-02/) — the fan-out you extend to the fleet.
- [Module 14.4 · Cilium and eBPF](../14-kubernetes-networking/04-cilium-and-ebpf/) —
  the CNI that Cluster Mesh builds on.
- [Module 05.6 · Crossplane](../05-infrastructure-as-code/06-crossplane/) — XRDs and
  Compositions, the abstraction the multi-cloud module reuses.
- A machine that can run **two** small [kind](https://kind.sigs.k8s.io/) clusters at
  once (Docker + `kubectl`), plus the [`argocd`](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
  and [`clusterctl`](https://cluster-api.sigs.k8s.io/user/quick-start) CLIs for the
  first two labs.

## A note on cost

The required labs run **free** on local kind. Module 1 uses two kind clusters and
ArgoCD; Module 2 runs Cluster API against the **CAPD (Docker)** provider, which builds
"clusters" as local containers with no cloud account. Modules 3 and 4 are **decision
and design** labs — the places where real multi-cloud networking and global load
balancers would cost money and need multiple cloud accounts are exactly where hands-on
practice stops paying off, so those are worksheet deliverables. Every cloud step (CAPG
on GKE, a real global LB, cross-cloud VPN) is clearly marked **optional** with an
accounts-and-cost note. The lesson is itself a phase theme: **model the fleet and its
cost before you provision it.**

---

Start with [**92 · Multi-Cluster Architecture →**](./01-multi-cluster-architecture/)
