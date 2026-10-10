# Module 10.5 — Multi-Cluster Kubernetes

> One cluster is never the end state. Isolation, availability, data residency, and simple
> scale limits push every serious platform to run *several* clusters — and now you have N
> API servers, N copies of RBAC, and N desired states to keep in sync. This module is
> about taming that: topologies, the management-cluster pattern, treating clusters
> themselves as declarative resources, and delivering one source of truth to a whole
> fleet.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Phase 3 · Kubernetes Fundamentals](../../03-kubernetes-fundamentals/), the GitOps ideas from [Phase 8](../../08-gitops/), and a machine that can run **two** small [kind](https://kind.sigs.k8s.io/) clusters at once.

## Learning objectives

By the end of this module you will be able to:

- Give concrete reasons to run **multiple clusters** — and reasons *not* to.
- Compare **hub-and-spoke, mesh, and hierarchical** topologies and the
  **management-cluster** pattern.
- Explain how **Cluster API** treats a cluster as a declarative resource.
- Deliver one application to a whole **fleet** with an Argo CD **ApplicationSet**, and
  manage **multi-cluster kubeconfig**.

---

## 1. Concept

### Why more than one cluster?

A single cluster is simpler, so you should stay on one as long as you can. You move to
several when one of these forces this on you:

- **Isolation / blast radius.** One cluster is one failure domain and one security
  boundary. A bad admission webhook, a runaway controller, or an etcd problem affects
  *everything* in it. Separating prod from dev — or tenant from tenant — caps the damage.
- **Availability.** A region or zone can fail. Running clusters across regions lets you
  survive the loss of one. A single cluster can't span the planet safely.
- **Regulatory / data residency.** "EU customer data stays in the EU" is often cleanest as
  a cluster in the EU, with a hard boundary rather than a soft namespace one.
- **Team ownership.** Some orgs give platform-critical teams their own cluster so they
  control upgrades and blast radius.
- **Scale limits.** Clusters have real ceilings (nodes, Pods, objects in etcd). Past a
  point you shard across clusters rather than grow one without bound.

The cost is real: every extra cluster is another control plane to run, secure, upgrade,
and pay for. **Multi-cluster is a tool for isolation and scale, not a default.**

### The new problem: N desired states

With many clusters, the naive workflow is `kubectl --context cluster-1 apply …`, then
`cluster-2`, then `cluster-3`. This is the same anti-pattern you've met all phase:
**imperative, drift-prone, and with no single source of truth.** Miss a cluster and it
silently diverges; there's no loop correcting it. The platform answer is the one you
already know — a **control loop with a declarative source of truth** — lifted to the fleet
level.

### Topologies

- **Hub-and-spoke (management cluster).** One **management/hub** cluster runs the
  controllers (Argo CD, Cluster API, policy) that provision and deliver to many
  **workload/spoke** clusters. Centralized control, clear separation. This is the most
  common platform shape and the one you'll build in the lab.
- **Mesh.** Clusters peer with each other (e.g. a service mesh spanning clusters) for
  cross-cluster traffic and failover. More capable, much more complex networking.
- **Hierarchical.** Management clusters managing other management clusters — large
  enterprises and cloud providers. Rare; mentioned for completeness.

### The management-cluster pattern

A **management cluster** hosts the brains and holds credentials to the workload clusters.
It's where your fleet controllers run. Two delivery styles:

- **Push.** The hub reaches out and applies to each spoke (the hub holds spoke
  credentials). Simple, but the hub is a high-value target with wide reach.
- **Pull.** An agent *inside* each spoke pulls its desired state from Git (Flux, or an
  Argo CD agent). The hub never needs inbound access to spokes; better blast-radius and
  security properties at scale.

### Cluster API: clusters as declarative resources

Here's the reconciliation loop one more time, aimed at the clusters themselves.
**Cluster API (CAPI)** represents a cluster as Kubernetes objects — `Cluster`,
`MachineDeployment`, `KubeadmControlPlane`, and infrastructure objects — in a management
cluster. A CAPI controller reconciles *actual infrastructure* toward that spec: it
provisions control-plane and worker machines, bootstraps them, and heals them. You
`kubectl apply` a cluster the same way you apply a Deployment.

```yaml
# ILLUSTRATIVE ONLY — do not apply. CAPI needs an infrastructure provider installed.
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: eu-prod
spec:
  clusterNetwork:
    pods: { cidrBlocks: ["192.168.0.0/16"] }
  controlPlaneRef: { kind: KubeadmControlPlane, name: eu-prod-cp }
  infrastructureRef: { kind: DockerCluster, name: eu-prod }  # or AWSCluster, GCPCluster…
```

- **Providers** implement the infrastructure half: CAPA (AWS), CAPG (GCP), CAPZ (Azure),
  vSphere, and a Docker provider for local testing. The top-level `Cluster` contract is
  the same regardless of where it runs.
- CAPI is **heavy** — it's a platform in its own right. We keep it conceptual here: the
  idea to carry forward is "clusters are cattle, defined and reconciled as code," the same
  as everything else in Kubernetes. (Many teams use their cloud's managed cluster +
  Terraform instead; Phase 19 goes deeper.)

### Fleet delivery: ApplicationSet

Once clusters exist and are **registered** with Argo CD, an **ApplicationSet** with a
**cluster generator** templates one Argo CD `Application` per matching cluster — so a
single object deploys (and keeps reconciled) an app across the whole fleet.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata: { name: demo-everywhere }
spec:
  generators:
    - clusters: {}          # every cluster registered with Argo CD
  template:
    metadata: { name: 'demo-{{name}}' }
    spec:
      project: default
      source: { repoURL: 'https://example.com/platform/apps', path: demo, targetRevision: main }
      destination: { server: '{{server}}', namespace: demo }
      syncPolicy: { automated: { prune: true, selfHeal: true } }
```

`selfHeal: true` is the fleet-level reconciliation loop: drift on any cluster is corrected
back to Git. Add a cluster, and the generator produces an `Application` for it
automatically — no per-cluster edits.

### Multi-cluster kubeconfig

A **kubeconfig** holds many **contexts** (cluster + user + namespace). One file can drive
every cluster; `kubectl config use-context` switches between them. This is fine for humans
and small fleets, but a single file full of long-lived, high-privilege tokens is a
liability — prefer short-lived, per-cluster credentials and let controllers (not people)
hold fleet-wide reach.

---

## 2. Why it matters for platform engineering

- **Isolation is a platform feature.** Offering "prod is a separate cluster" or "your
  regulated workload runs in-region" is a capability your platform provides — and you need
  to deliver to those clusters consistently.
- **Consistency across the fleet.** The hard part of N clusters isn't creating them; it's
  keeping them *the same*. GitOps fan-out (ApplicationSet) is how one paved road reaches
  every cluster without snowflakes.
- **Clusters as cattle.** Treating clusters as declarative, reproducible resources (CAPI
  or Terraform) is what lets you run many without drowning in manual toil.
- **Security posture.** Where credentials live and which way delivery flows (push vs pull)
  is a core platform security decision once more than one cluster is in play.

---

## 3. Mental model

Picture a **hub** holding the brains and a declarative source of truth, fanning work out
to many **spokes** — and the same self-healing loop running at the fleet level.

```text
                         Git (desired state of the fleet)
                                      │
                   ┌──────────────────▼──────────────────┐
                   │        MANAGEMENT (hub) cluster       │
                   │   Argo CD ApplicationSet (clusters)   │
                   │   Cluster API (clusters as resources) │
                   └───────┬───────────────┬───────────────┘
                reconcile  │               │  reconcile
                           ▼               ▼
                   ┌───────────────┐ ┌───────────────┐   ... (add a spoke →
                   │  spoke: dev   │ │  spoke: prod  │        the generator makes
                   │  (context A)  │ │  (context B)  │        an Application for it)
                   └───────────────┘ └───────────────┘
```

Two things to remember: **the fleet is just the reconciliation loop again** (Git is
desired state, a hub controller closes the gap on every cluster), and **clusters
themselves are resources** you define and reconcile, not pets you hand-build.

---

## 4. Minimal implementation

Feel the problem before the tool. With two local clusters you get two contexts; deploying
to "everywhere" by hand is two commands — and already smells of drift:

```bash
kubectl config get-contexts                     # kind-hub, kind-spoke
kubectl --context kind-hub   create deployment demo --image=nginx:1.27
kubectl --context kind-spoke create deployment demo --image=nginx:1.27
# Two clusters = two commands. Fifty clusters = a script that drifts and lies.
```

The declarative answer registers the spokes once and lets one object own the fan-out:

```bash
# on the hub: one ApplicationSet deploys demo to EVERY registered cluster, and self-heals
kubectl --context kind-hub apply -f applicationset.yaml
```

You've turned "apply to each cluster, hope none drift" into "declare it once; a loop keeps
all clusters correct." That's the whole move, and it's the lab.

---

## 5. Hands-on lab

You'll stand up **two** kind clusters (a hub and a spoke), manage both from one kubeconfig
with contexts, install Argo CD on the hub, register the spoke, and apply an
**ApplicationSet** cluster generator that deploys a demo app to both clusters at once. CAPI
stays conceptual (it needs an infra provider); everything you *run* is free and local.

➡️ **[Start the lab: Two clusters, one fleet](./lab/README.md)**

---

## 6. Production considerations

- **Credentials are the crown jewels.** A hub with push access to every spoke is a huge
  blast radius. Prefer short-lived, per-cluster credentials, scope them tightly, and
  consider **pull-based** agents so spokes have no inbound exposure.
- **Standardize or drown.** Keep clusters identical via generators/overlays and a single
  Git source. Every manual, per-cluster tweak is a future snowflake you'll debug at 2am.
- **Roll out in waves.** Don't change all clusters at once. Use generators and sync waves
  to canary a change on one cluster, then widen — the fleet version of a progressive
  rollout.
- **Mind version skew.** Clusters drift in Kubernetes version; test against the spread you
  actually run and have an upgrade strategy (CAPI or managed-provider upgrades).
- **Cross-cluster networking isn't free.** Services don't resolve across clusters by
  default. If you need it, adopt **Submariner** or a multi-cluster service mesh
  deliberately — and prefer loosely coupled designs that don't.
- **Right-size the fleet.** Each cluster has fixed overhead. Sometimes namespaces +
  quotas + RBAC in one cluster is the better isolation story than another whole cluster.

---

## 7. Common mistakes

- **Clusters as pets.** — Clicking clusters up in a console, each slightly different, with
  no reproducible definition. *Fix:* define clusters as code (CAPI or Terraform); make
  them rebuildable.
- **Imperative fleet deploys.** — `kubectl apply` to each cluster by hand or in a loop,
  which drifts the moment one call fails. *Fix:* GitOps fan-out (ApplicationSet/Fleet) with
  self-heal.
- **One god credential on the hub.** — A single long-lived, cluster-admin token for every
  spoke. *Fix:* per-cluster, least-privilege, short-lived credentials; consider pull
  delivery.
- **Assuming cross-cluster networking works.** — Expecting a Service in cluster A to be
  reachable from cluster B. *Fix:* it isn't, without explicit multi-cluster discovery;
  design for it or avoid needing it.
- **Snowflake clusters.** — Each cluster configured differently, so nothing is
  reproducible and every incident is bespoke. *Fix:* standardize via generators and a
  single source of truth.
- **Multi-cluster when one would do.** — Splitting into clusters for isolation that
  namespaces + quotas + policy already provide. *Fix:* reserve separate clusters for hard
  boundaries (security, region, availability), not routine separation.

---

## 8. Assessment

**Knowledge checks**

1. Give three distinct reasons an organization runs multiple clusters, and one reason not
   to.
2. In the hub-and-spoke pattern, what runs on the management cluster, and what runs on the
   workload clusters?
3. What does Cluster API treat a *cluster* as, and what does that let you do with
   `kubectl`?
4. What does an ApplicationSet **cluster generator** produce, and what happens when you
   register a new cluster?
5. Contrast **push** and **pull** multi-cluster delivery in terms of where credentials
   live and inbound access.

**Concept exercise**

> Explain how you'd keep the same application deployed and continuously in sync across 20
> clusters, automatically repairing drift on any of them — **without using the words
> "Argo CD," "ApplicationSet," or "GitOps."** Describe it as a control loop with a source
> of truth.

**Debugging / trade-off exercise**

> A company adopted "a cluster per team for isolation" and now runs 50 clusters that were
> each hand-configured; upgrades take weeks and no two clusters are alike. What went wrong,
> and what three changes would you make to get the fleet under control? Separately: name a
> case where a *single* cluster with strong namespace isolation is the better call.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Isolation/blast radius, availability (region/zone failure), data residency, team
  ownership, or scale limits — any three. A reason not to: the operational and cost
  overhead of running, securing, and upgrading each extra cluster.
- **Q2:** The management cluster runs the fleet controllers (Argo CD, Cluster API, policy)
  and holds credentials; workload clusters run the actual application workloads.
- **Q3:** CAPI treats a cluster as a declarative resource (`Cluster` and friends), so you
  create, scale, upgrade, and delete clusters with `kubectl apply`, reconciled by a
  controller.
- **Q4:** It templates one Argo CD `Application` per matching cluster; registering a new
  cluster makes the generator produce an `Application` for it automatically, with no
  per-cluster edits.
- **Q5:** Push: the hub holds spoke credentials and reaches into each spoke (wide blast
  radius, needs outbound to spokes). Pull: an agent in each spoke pulls from Git, so the
  hub needs no inbound access to spokes — better isolation at scale.
- **Debugging:** The clusters are pets (hand-configured, non-reproducible) with imperative
  management. Fix: define clusters as code (CAPI/Terraform), standardize config via
  generators/overlays from one Git source, and deliver with GitOps fan-out + self-heal. A
  single cluster with namespaces, quotas, RBAC, and policy is better when the isolation you
  need is between *teams/workloads* rather than a hard security, region, or availability
  boundary.

</details>

---

## 9. Further reading

- The Cluster API Book — [Introduction and concepts](https://cluster-api.sigs.k8s.io/)
- Argo CD — [ApplicationSet and the cluster generator](https://argo-cd.readthedocs.io/en/stable/user-guide/application-set/)
- Argo CD — [Declaratively managing clusters](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/#clusters)
- Kubernetes — [Configure access to multiple clusters (kubeconfig)](https://kubernetes.io/docs/tasks/access-application-cluster/configure-access-multiple-clusters/)
- Submariner — [Cross-cluster service discovery](https://submariner.io/)
- Istio — [Multicluster deployment models](https://istio.io/latest/docs/ops/deployment/deployment-models/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 10.4 — API Extension Patterns](../04-api-extension-patterns/)
· _Next:_ [Phase 11 · Observability Engineering →](../../11-observability-engineering/)
