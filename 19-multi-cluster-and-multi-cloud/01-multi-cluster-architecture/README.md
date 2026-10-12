# Module 19.1 — Multi-Cluster Architecture

> [Module 10.5](../../10-kubernetes-advanced/05-multi-cluster-kubernetes/) argued
> *why* a platform ends up with more than one cluster and showed the hub-and-spoke
> shape. This module is about the **decisions** that turn a pile of clusters into an
> architecture: which boundary you cut along, where identity lives, how (and whether)
> services talk across clusters, and how one GitOps source of truth reaches the right
> subset of a fleet. The recurring discipline is the course's: add a cluster only for
> a boundary a namespace cannot draw, and connect clusters only when you can name why.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 10.5 · Multi-Cluster Kubernetes](../../10-kubernetes-advanced/05-multi-cluster-kubernetes/), [Module 08.3 · ApplicationSets](../../08-gitops/03-argocd-applicationsets/), and a machine that can run **two** small [kind](https://kind.sigs.k8s.io/) clusters with the `argocd` CLI.

## Learning objectives

By the end of this module you will be able to:

- Choose a **segmentation axis** — per environment, per team, per region — and justify
  when a namespace boundary is the better answer.
- Apply the **management-cluster pattern** and reason about push vs pull delivery and
  blast radius.
- Compare **cross-cluster service discovery** — Cilium Cluster Mesh, Istio
  multi-cluster, Submariner — and design loosely coupled systems that avoid needing it.
- Explain **multi-cluster RBAC** as centralized identity with distributed enforcement.
- Target a **subset of the fleet** with an ApplicationSet cluster generator and a label
  selector.

---

## 1. Concept

### Start from the boundary, not the cluster count

Module 10.5 listed the forces that push you past one cluster: blast radius, regional
availability, data residency, team ownership, and scale ceilings. The architecture
question is the next one: **along which boundary do you cut?** A cluster is the
strongest isolation unit Kubernetes offers — its own API server, etcd, RBAC, and
failure domain — so you spend one each time you draw a line that a softer boundary
(namespace + quota + NetworkPolicy + RBAC) cannot hold.

Three segmentation axes dominate, and real platforms combine them:

- **Per environment (dev / staging / prod).** The most common first split: it keeps a
  broken dev controller or a noisy load test away from production and gives prod its own
  version, change-freeze calendar, and blast radius — none of which a namespace can draw.
- **Per team / tenant.** A whole cluster for a team (or external tenant) that needs control
  over upgrades, cluster-wide resources (CRDs, admission webhooks), or a hard compliance
  boundary. Expensive — reserve it for genuine isolation, not org-chart tidiness; most teams
  are better served by a namespace with quotas.
- **Per region.** Required for availability (survive a region outage) and residency ("EU
  data stays in the EU") — a boundary physics and law draw for you; you just make it explicit.

These multiply. A modest platform is often an **environment × region** grid —
`dev-eu`, `prod-eu`, `prod-us` — plus a management cluster. The number of clusters is
an *output* of the boundaries you chose, never a target you pick first.

```text
            region →        eu-west            us-east
 environment ↓        ┌───────────────┐  ┌───────────────┐
      prod            │   prod-eu     │  │   prod-us     │   ← availability + residency
                      └───────────────┘  └───────────────┘
      staging         │  staging-eu   │       (none)         ← cost: only where needed
      dev             │   dev-eu      │       (none)
```

### The management cluster, and where the brains live

As in 10.5, a **management (hub) cluster** runs the controllers that provision and
deliver to **workload (spoke) clusters** — ArgoCD, Cluster API, policy — and holds the
credentials to reach them. Two delivery directions, recapped because the security
trade-off is central:

- **Push:** the hub holds spoke credentials and applies into each spoke. Simple;
  the hub is a high-value target with wide reach.
- **Pull:** an agent inside each spoke pulls its desired state from Git. The hub needs
  no inbound path to spokes — better blast radius at fleet scale.

The management cluster is the crown jewels: compromise it and you own every workload
cluster. It gets the strictest RBAC, the tightest network exposure, and ideally
pull-based delivery so it never needs standing credentials into production.

### Multi-cluster traffic: ingress per cluster vs a global front door

Each cluster still has its own ingress/Gateway and its own external IP. Two patterns
put users in front of a fleet:

- **Ingress per cluster.** Every cluster is independently reachable (its own DNS name
  or IP). Simple, and fine when clients know which cluster to hit (internal tools,
  region-pinned apps).
- **Global load balancer in front.** One hostname/anycast IP routes each user to the
  nearest healthy cluster and fails over when a region dies. This is what makes an
  environment × region grid feel like one service. It is the whole of
  [Module 19.4](../04-global-load-balancing-and-edge/); here, just know the fleet is
  *built* to sit behind it.

### Cross-cluster service discovery: the default is "no"

Here is the fact that surprises people: **a Service in cluster A is not reachable from
cluster B.** Each cluster has its own `ClusterIP` range and its own DNS
(`svc.namespace.svc.cluster.local` resolves only locally). Pods do not route to another
cluster's pod network. If `checkout` in `prod-us` needs `payments` in `prod-eu`, nothing
connects them until you build it.

Three tools build it, in rising order of capability and cost:

- **Cilium Cluster Mesh.** Builds on the Cilium CNI you met in
  [Module 14.4](../../14-kubernetes-networking/04-cilium-and-ebpf/). It connects the pod
  networks of meshed clusters and lets a Service be marked **global**
  (`service.cilium.io/global: "true"`), so it load-balances across clusters and fails
  over automatically. L3/L4, eBPF-fast, no sidecars. Best when you already run Cilium.
- **Istio multi-cluster.** Extends an Istio service mesh across clusters with an
  east-west gateway, giving cross-cluster mTLS, L7 routing, and a unified service
  registry. Powerful, but it is a mesh — real proxy and operational overhead
  (see [Module 14.6](../../14-kubernetes-networking/06-service-mesh-reference/)).
- **Submariner.** CNI-agnostic: it builds encrypted tunnels between clusters and uses a
  **Lighthouse** DNS component so `service.ns.svc.clusterset.local` resolves across the
  clusterset. Good when clusters run different CNIs and you only need connectivity.

The strongest architectural advice is to **not need it.** Cross-cluster synchronous
calls couple two failure domains — the thing you split clusters to decouple. Prefer
designs where each cluster is self-sufficient and clusters share **data**
(async replication, a message bus, a shared datastore) rather than **live request
paths**. Reserve Cluster Mesh and friends for the genuine cases: active-active data
locality, gradual migration, or a service that truly must span regions.

### Multi-cluster RBAC: one identity, many enforcers

Ten clusters must not mean ten user databases. The pattern is **centralized identity,
distributed enforcement**:

- **Centralized identity.** Every cluster trusts the same identity provider (OIDC — your
  IdP, Entra ID, Okta, Google). A person or workload has *one* identity across the fleet;
  no per-cluster local accounts or long-lived kubeconfig tokens handed around.
- **Distributed enforcement.** Each cluster still owns its own `Role`/`ClusterRole`
  bindings and decides what that identity may do *there*. A platform group might be
  admin on `dev-eu` and read-only on `prod-eu`. Enforcement is local (the API server
  checks), but the identity it checks is global.

Deliver those bindings the same way you deliver everything else — through GitOps — so
"who can do what, where" is itself declarative and auditable.

### Multi-cluster GitOps: target segments, not just "everywhere"

Module 10.5's ApplicationSet used `clusters: {}` — deploy to *every* registered cluster.
Real fleets are segmented, so you target subsets. The cluster generator exposes each
registered cluster's **labels**, and a selector filters them:

```yaml
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: prod        # only clusters labelled prod
  template:
    metadata:
      name: 'payments-{{name}}'
    spec:
      source:
        repoURL: https://example.com/platform/apps
        path: 'payments/overlays/{{metadata.labels.environment}}'   # per-segment config
        targetRevision: main
      destination:
        server: '{{server}}'
        namespace: payments
```

Label a cluster `environment=prod,region=eu` when you register it, and one
ApplicationSet rolls the prod overlay to exactly the prod clusters — and picks up a new
prod cluster automatically the day you add one. This is the segmentation strategy made
executable, and it is the lab.

---

## 2. Why it matters for platform engineering

- **Segmentation is a product decision.** "Prod is a separate cluster," "your regulated
  workload runs in-region," "your team gets its own cluster" are *capabilities* your
  platform offers. Choosing the axes deliberately is platform design, not an accident of
  growth.
- **Consistency is the hard part.** Creating clusters is easy; keeping a segmented fleet
  identical is the work. Label-targeted GitOps fan-out is how one paved road reaches each
  segment without snowflakes.
- **Identity cannot be per-cluster.** Without centralized identity, a ten-cluster fleet
  becomes ten access-control problems and a pile of long-lived tokens — an audit
  nightmare and a breach waiting to happen.
- **Coupling is the silent cost.** Whether you ever need Cluster Mesh is decided by how
  loosely you architect services. A platform that encourages cross-cluster synchronous
  calls has quietly rebuilt one big failure domain out of many small ones.

## 3. Mental model

**Cut along boundaries you cannot erase; keep clusters independent; connect only when
you can name why.** Hold this picture: a management cluster drives a segmented grid, one
GitOps source targets segments by label, and most services never cross a cluster line.

```text
                    Git (desired state, per segment via labels)
                                      │
                     ┌────────────────▼─────────────────┐
                     │        MANAGEMENT cluster          │
                     │  ArgoCD ApplicationSets (selector) │
                     │  Cluster API · policy · OIDC trust │
                     └───┬──────────────┬─────────────┬───┘
            env=prod     │   env=prod   │   env=dev   │   (label selectors
            region=eu    ▼   region=us  ▼   region=eu ▼    route config to
                 ┌────────────┐ ┌────────────┐ ┌────────────┐  the right segment)
                 │  prod-eu   │ │  prod-us   │ │   dev-eu   │
                 │  (self-    │ │  (self-    │ │  (self-    │
                 │ sufficient)│ │ sufficient)│ │ sufficient)│
                 └─────┬──────┘ └──────┬─────┘ └────────────┘
                       └─ async data ──┘   ← share DATA, not live request paths
                          (replication)       (cross-cluster calls only when justified)
```

Two rules to keep: **the fleet is the reconciliation loop again** (Git is desired state;
a hub closes the gap on each segment), and **a cluster line is a failure-domain line** —
every synchronous call you draw across it trades away the isolation you paid for.

## 4. Minimal implementation

Feel the targeting problem before the tool. "Deploy to everything" is one line; "deploy
the prod overlay to prod only, and self-heal" is the real requirement — and doing it by
hand drifts the moment you add a cluster:

```bash
# imperative, per-cluster, drift-prone
kubectl --context prod-eu apply -k payments/overlays/prod
kubectl --context prod-us apply -k payments/overlays/prod
# forget dev? deploy prod config to dev by mistake? nothing stops you.
```

The declarative answer labels clusters once and lets a selector own the fan-out:

```bash
# register each cluster WITH labels (done once), e.g. prod-eu:
argocd cluster add kind-prod-eu --name prod-eu \
  --label environment=prod --label region=eu

# then one ApplicationSet with a selector targets the segment and self-heals
kubectl --context mgmt apply -f applicationset-by-label.yaml
```

You have turned "apply the right thing to the right clusters, hope none drift" into
"declare it once; a loop keeps each segment correct, and new clusters inherit their
segment automatically." That is the whole move, and it is the lab.

## 5. Hands-on lab

You'll run **two** kind clusters — a management cluster and a workload cluster —
register the workload cluster with ArgoCD **carrying segment labels**, and deploy with
an **ApplicationSet cluster generator plus a label selector** so config lands by segment,
not blindly everywhere. You'll then add a second segment label and watch targeting
change with zero edits to the app. Everything runs free and local; cross-cluster service
discovery stays conceptual (it needs a real multi-node network).

➡️ **[Start the lab: Segment a two-cluster fleet](./lab/README.md)**

## 6. Production considerations

- **Segment on hard boundaries only.** Environment, region, and genuine
  security/compliance isolation justify a cluster. "Each team wants their own" usually
  does not — offer namespaces with quotas and RBAC first, and escalate to a cluster when
  a team actually needs cluster-scoped control.
- **Centralize identity from day one.** Wire every cluster to the same OIDC provider and
  deliver RBAC bindings via GitOps. Retrofitting identity onto a sprawled fleet is
  painful; starting there is nearly free.
- **Treat the management cluster as crown jewels.** Strict RBAC, minimal exposure,
  pull-based delivery where possible, and no standing human credentials into prod.
- **Adopt cross-cluster discovery deliberately.** Cluster Mesh / Istio / Submariner each
  add a networking layer to run, secure, and debug. Require a named use case, and prefer
  async data sharing over synchronous cross-cluster calls.
- **Standardize add-ons per segment.** Ingress, logging, policy, and cert management
  should be identical within a segment and versioned in Git. Every manual per-cluster
  tweak is a future 2 a.m. snowflake.
- **Plan the front door early.** Decide ingress-per-cluster vs global LB before you have
  users in two regions; it shapes DNS, certificates, and health-check design
  ([Module 19.4](../04-global-load-balancing-and-edge/)).

## 7. Common mistakes

- **Cluster sprawl.** — A cluster per app or per team "for isolation" that namespaces,
  quotas, and NetworkPolicy already provide. Every cluster is fixed overhead to run,
  secure, and upgrade. *Fix:* reserve clusters for hard boundaries; default to namespaces.
- **Snowflake segments.** — `prod-eu` and `prod-us` drift to different versions and
  add-ons because each was tweaked by hand. *Fix:* one Git source, label-targeted
  ApplicationSets, identical overlays per segment.
- **Assuming cross-cluster DNS works.** — Expecting `payments.payments.svc` in one
  cluster to resolve from another. It does not. *Fix:* design self-sufficient clusters;
  add Cluster Mesh/Submariner only for a named need.
- **Per-cluster identity stores.** — Local accounts and long-lived kubeconfig tokens
  copied around the fleet. *Fix:* central OIDC, short-lived credentials, RBAC via GitOps.
- **A service mesh across clusters by default.** — Reaching for Istio multi-cluster before
  a problem requires it, buying latency and operational load for every service. *Fix:*
  name the problem first; most fleets never need it.
- **Cross-cluster synchronous coupling.** — `checkout` calls `payments` in another region
  on the hot path, so one region's outage cascades. *Fix:* keep request paths in-cluster;
  share data asynchronously across clusters.

## 8. Assessment

**Knowledge checks**

1. Name the three common segmentation axes and give a boundary each one draws that a
   namespace cannot.
2. Why is a Service in cluster A not reachable from cluster B by default, and what two
   things differ between the clusters that cause this?
3. Contrast Cilium Cluster Mesh, Istio multi-cluster, and Submariner in one line each.
4. Explain "centralized identity, distributed enforcement" for multi-cluster RBAC.
5. What does adding a `selector` to an ApplicationSet cluster generator let you do that
   `clusters: {}` does not?

**Concept exercise**

> Explain how you would keep the *production* overlay of an app deployed and
> continuously reconciled on exactly your production clusters across two regions — and
> automatically covering a third prod cluster you add next month — **without using the
> words "ArgoCD," "ApplicationSet," or "label."** Describe it as a control loop with a
> selector over a set.

**Architecture / trade-off exercise**

> A team asks the platform to make `orders` (in `prod-us`) call `inventory` (in
> `prod-eu`) directly, synchronously, on every checkout. Walk through the failure-domain
> and latency consequences, name what you would have to adopt to make it work, and
> propose a loosely coupled alternative. Separately: when *is* cross-cluster service
> discovery the right call?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Environment (own upgrade cadence / change freeze / blast radius), team-or-tenant
  (cluster-scoped CRDs & webhooks, hard compliance isolation), region (survive a regional
  outage, data residency). A namespace shares one API server, one control-plane version,
  and one failure domain — it cannot draw any of those lines.
- **Q2:** Each cluster has its own pod/Service CIDR and its own DNS; `cluster.local`
  resolves only locally and pods do not route to another cluster's network, so there is no
  path and no name across clusters until you build one.
- **Q3:** Cluster Mesh — eBPF L3/L4 global Services across meshed Cilium clusters, no
  sidecars. Istio multi-cluster — L7 mesh with cross-cluster mTLS and a shared registry via
  an east-west gateway, higher overhead. Submariner — CNI-agnostic encrypted tunnels plus
  Lighthouse DNS for a clusterset.
- **Q4:** Every cluster trusts one identity provider (a person/workload has a single
  federated identity), but each cluster owns its own RBAC bindings and decides locally what
  that identity may do there.
- **Q5:** It targets a *subset* of the fleet by cluster labels (e.g. only `environment=prod`)
  and can template per-segment config, instead of deploying identically to every registered
  cluster.
- **Trade-off:** The synchronous cross-region call couples two failure domains and adds
  cross-region latency to every checkout, so a `prod-eu` blip now breaks `prod-us` orders.
  Making it "work" needs cross-cluster discovery (Cluster Mesh/Istio/Submariner) *and*
  accepting the coupling. Better: keep an inventory replica or cache in `prod-us` and
  reconcile asynchronously, so each region serves checkout on its own. Cross-cluster
  discovery earns its place for active-active data locality, phased migration between
  clusters, or a genuinely global service — a named need, not a default.

</details>

## 9. Further reading

- Cilium — [Cluster Mesh guide](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/)
- Istio — [Multicluster deployment models](https://istio.io/latest/docs/ops/deployment/deployment-models/)
- Submariner — [Architecture and Lighthouse service discovery](https://submariner.io/getting-started/architecture/)
- Argo CD — [ApplicationSet cluster generator](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Cluster/)
- Kubernetes — [Using OpenID Connect (OIDC) tokens for cluster auth](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens)
- CNCF — [Introduction to multicluster (kubernetes.io)](https://kubernetes.io/docs/concepts/cluster-administration/#planning-a-cluster)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 15 · Multi-Cluster and Multi-Cloud overview](../README.md) · _Next:_ [Module 19.2 — Fleet Management with Cluster API →](../02-fleet-management-with-cluster-api/)
