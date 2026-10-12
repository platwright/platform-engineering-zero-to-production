# Module 19.2 — Fleet Management with Cluster API

> [Module 10.5](../../10-kubernetes-advanced/05-multi-cluster-kubernetes/) showed one
> illustrative `Cluster` object and promised "clusters are cattle, defined as code."
> This module makes that real. **Cluster API (CAPI)** turns a management cluster into a
> control plane for *other clusters*: you `kubectl apply` a cluster, a controller
> provisions and heals it, you bump a field to upgrade it, and you delete the object to
> tear it down. You'll run it locally with the **Docker provider** — a real reconcile
> loop building real "clusters" as containers, for free — and meet **ClusterClass**, the
> template that makes a whole fleet reproducible.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 10.5 · Multi-Cluster Kubernetes](../../10-kubernetes-advanced/05-multi-cluster-kubernetes/), Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, and the [`clusterctl`](https://cluster-api.sigs.k8s.io/user/quick-start) CLI. The lab runs on the local **CAPD (Docker)** provider — no cloud account.

## Learning objectives

By the end of this module you will be able to:

- Explain the **CAPI resource model** — `Cluster`, control-plane, `MachineDeployment`,
  and the bootstrap/infrastructure provider split.
- Distinguish a **management cluster** from **workload clusters** and name the role of a
  provider (CAPD, CAPA, CAPG, CAPZ).
- Template a fleet with **ClusterClass** and stamp instances with a `topology`.
- Perform a **declarative upgrade** and reason about **auto-scaling** node groups.
- Bootstrap a brand-new cluster into a **GitOps-ready** state automatically.

---

## 1. Concept

### The reconciliation loop, aimed at clusters

You have used one idea all course: declare desired state, let a controller close the gap
and heal drift. Deployments do it for Pods. **Cluster API does it for clusters.** In a
**management cluster**, a cluster is a set of Kubernetes objects; CAPI controllers watch
them and reconcile *actual infrastructure* — they provision machines, bootstrap
Kubernetes onto them, join them, and replace them when they die. Create the objects and a
cluster appears; delete them and it is gone.

The core objects, and the separation that makes CAPI portable:

```text
  Cluster ───────────────┬──────────────────────────────┐
  (the contract)         │ controlPlaneRef               │ infrastructureRef
                         ▼                               ▼
          KubeadmControlPlane              DockerCluster | AWSCluster | GCPCluster …
          (control-plane provider:         (infrastructure provider:
           runs/upgrades the API server)    where machines & networks come from)
                         │
                         │ workers
                         ▼
          MachineDeployment ──▶ Machine ──┬── bootstrap: KubeadmConfig
          (like a Deployment,             │   (how a node joins: cloud-init + kubeadm)
           but for nodes)                 └── infrastructure: DockerMachineTemplate …
```

Three provider *kinds* cooperate, and each is swappable:

- **Bootstrap provider** — turns a blank machine into a Kubernetes node (the Kubeadm
  bootstrap provider writes cloud-init that runs `kubeadm join`).
- **Control-plane provider** — manages the control plane's lifecycle and upgrades
  (`KubeadmControlPlane`).
- **Infrastructure provider** — creates the actual machines, load balancers, and
  networks. This is the only part that is cloud-specific.

Because only the infrastructure refs change, **the top-level `Cluster` contract is
identical** whether you target Docker, AWS, GCP, or Azure. That portability is the whole
point.

### Management vs workload, and providers

- A **management cluster** runs the CAPI controllers and holds the cluster objects. It is
  small, long-lived, and precious — it is the control plane for your fleet.
- **Workload clusters** are what CAPI creates: the clusters your applications actually run
  on. They are disposable and reproducible.
- A **provider** teaches CAPI about a target. `clusterctl init --infrastructure docker`
  installs **CAPD**, which builds workload "clusters" as Docker containers on your host —
  perfect for learning and CI. The cloud providers are **CAPA** (AWS/EKS), **CAPG**
  (GCP/GKE), and **CAPZ** (Azure/AKS); you swap the provider and the infrastructure refs,
  and everything else — the workflow, the objects, the upgrade mechanics — stays the same.

### ClusterClass: a template for clusters

Authoring a raw `Cluster` means writing six-plus coordinated objects (control plane
template, worker templates, infra templates, bootstrap templates) correctly, every time.
Across a fleet that is copy-paste drift waiting to happen — the cluster-level version of
the problem ApplicationSets solved for apps.

**ClusterClass** fixes it. A platform team authors *one* `ClusterClass` — the templates,
plus declared **variables** (e.g. `workerMachineCount`, Kubernetes `version`) and
**patches** that apply them — and then each cluster is a tiny `Cluster` object with a
`spec.topology` that references the class and fills in the variables:

```yaml
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: team-a-prod
spec:
  topology:
    class: platform-cluster       # the ClusterClass authored once
    version: v1.31.2
    controlPlane:
      replicas: 1
    workers:
      machineDeployments:
        - class: default-worker
          name: md-0
          replicas: 3
```

That is the entire definition of a cluster. ClusterClass is to clusters what a Deployment
template is to Pods, or a Crossplane Composition is to cloud resources: **platform
opinions encoded once, instances stamped out cheaply.** It is the paved road for clusters
themselves.

### Declarative upgrades and auto-scaling

- **Upgrades.** Change `spec.topology.version` from `v1.31.2` to `v1.32.x` and commit.
  CAPI performs a **rolling upgrade**: it provisions new control-plane machines at the new
  version, moves etcd and the API server, then rolls the worker `MachineDeployments` —
  cordon, drain, replace — honoring your surge settings. No SSH, no manual `kubeadm
  upgrade` per node. The change is a diff in Git: reviewable, auditable, revertible.
- **Auto-scaling node groups.** A `MachineDeployment`'s `replicas` is a number you can set
  — or let the **cluster-autoscaler** set, by annotating min/max so it adds and removes
  worker Machines with demand. For provider-managed node groups there is **`MachinePool`**
  (e.g. an AWS ASG or a GKE node pool managed as one CAPI object). Either way, node
  capacity becomes declarative and elastic instead of hand-provisioned.

### Bootstrapping a cluster into a usable state

A fresh CAPI cluster is empty — no CNI, no ingress, no GitOps agent. You do **not** want
to `kubectl apply` add-ons by hand onto every new cluster (snowflakes again). Two
declarative patterns close the gap automatically:

- **`ClusterResourceSet`** — a CAPI object that applies a set of manifests (a CNI, say) to
  every cluster matching a label, as soon as it exists.
- **GitOps hand-off** — install an ArgoCD/Flux agent as part of bootstrap, then let GitOps
  take over all further add-ons (the Cluster API Add-on Provider for Flux, or an
  ApplicationSet from Module 19.1). The result: *create a cluster → it comes up already
  connected to the platform's source of truth*, production-ready without a human.

This is the end-to-end platform move — **cluster creation and app delivery are both just
reconciliation loops**, chained so one triggers the other.

---

## 2. Why it matters for platform engineering

- **Clusters become cattle at scale.** CAPI is what lets a small team run dozens of
  clusters without drowning in manual provisioning and upgrade toil.
- **Lifecycle is auditable.** Create, scale, upgrade, and delete are diffs in Git, reviewed
  by PR and reconciled by a controller — the same governance you have for apps, now for
  the clusters under them.
- **ClusterClass is a paved road for infrastructure.** It encodes the platform's opinions
  (sizes, versions, add-ons) once, so every team's cluster is consistent and compliant by
  default instead of by reminder.
- **Fleet-wide upgrades stop being heroics.** Declarative, rolling, canary-able upgrades
  replace the per-cluster, late-night `kubeadm` ritual that creates version-skew
  snowflakes.

## 3. Mental model

**Kubernetes already reconciles desired state into running software; CAPI reconciles
desired state into running *clusters*. ClusterClass is the Deployment template, and each
`Cluster` with a `topology` is a replica.**

```text
        Git (desired state: ClusterClass + Cluster topologies)
                              │  kubectl apply / GitOps
                ┌─────────────▼──────────────┐
                │      MANAGEMENT cluster      │
                │  CAPI controllers:           │
                │   bootstrap · control-plane  │
                │   · infrastructure provider  │
                └───────┬───────────────┬──────┘
          reconcile     │               │     reconcile
                        ▼               ▼
              ┌───────────────┐ ┌───────────────┐   change version → rolling upgrade
              │ workload: dev │ │ workload: prod │   change replicas → scale nodes
              │ (from class)  │ │ (from class)   │   delete object → cluster destroyed
              └───────────────┘ └───────────────┘   add a label → ClusterResourceSet adds CNI
```

Rules to keep: **the management cluster is the brain** (protect and back it up); **never
hand-edit a workload cluster** — change its spec and let CAPI reconcile; and **author a
ClusterClass, not N raw clusters**, so the fleet stays a template with parameters, not a
pile of snowflakes.

## 4. Minimal implementation

Feel the loop with the Docker provider — real CAPI, no cloud. Turn a kind cluster into a
management cluster, then ask it for a workload cluster:

```bash
# 1. a management cluster, then install CAPI with the Docker infrastructure provider
kind create cluster --name capi-mgmt
clusterctl init --infrastructure docker

# 2. generate a workload cluster definition and apply it (the "apply a cluster" moment)
clusterctl generate cluster demo --flavor development \
  --kubernetes-version v1.31.2 --control-plane-machine-count 1 --worker-machine-count 1 \
  > demo-cluster.yaml
kubectl apply -f demo-cluster.yaml

# 3. watch infrastructure get reconciled into existence
kubectl get cluster,machine
```

You applied a cluster and a controller is building it — control plane, a worker, the
networking — with no SSH and no cloud console. That is the entire thesis of CAPI, and the
lab turns it into a ClusterClass-templated, upgradeable, GitOps-ready workflow.

## 5. Hands-on lab

You'll turn a kind cluster into a **management cluster**, install Cluster API with the
**Docker provider**, author a **ClusterClass**, stamp a **workload cluster** from it with a
tiny `topology`, pull the new cluster's kubeconfig and run a workload on it, then perform a
**declarative upgrade** by changing one field. CAPG/GKE appears as an **optional** cloud
reference you can read but need not run. Everything required is free and local.

➡️ **[Start the lab: Clusters as code with CAPD](./lab/README.md)**

## 6. Production considerations

- **The management cluster is a single point of truth — treat it like one.** Make it HA,
  back up its etcd (and the CAPI objects), and know how to **`clusterctl move`** (pivot) the
  fleet to a rebuilt management cluster for disaster recovery.
- **Never reconcile by hand.** Changing a workload cluster with imperative `kubectl` behind
  CAPI's back creates drift CAPI will fight or overwrite. Change the spec; let the loop act.
- **Template everything with ClusterClass.** Raw per-cluster manifests re-introduce
  snowflakes. Variables and patches keep the fleet uniform and upgrades uniform.
- **Upgrade in waves with skew in mind.** Canary a version bump on one non-critical cluster,
  watch it, then widen. Respect Kubernetes control-plane/worker skew rules and CAPI's own
  provider contract versions.
- **Scope provider credentials tightly.** CAPA/CAPG/CAPZ hold cloud credentials that can
  create machines and networks — least privilege, short-lived, and audited.
- **Bootstrap to production-ready, not blank.** Pair CAPI with `ClusterResourceSet` or a
  GitOps agent so new clusters arrive with CNI, policy, and the platform's apps — never a
  bare control plane someone has to finish by hand.
- **CAPD is for learning and CI, not production.** The Docker provider builds containers on
  one host; use a real infrastructure provider (or a managed service) for anything that
  serves traffic.

## 7. Common mistakes

- **An unprotected management cluster.** — No HA, no etcd backup, no pivot plan; lose it and
  you lose declarative control of the whole fleet. *Fix:* HA control plane, regular backups,
  a tested `clusterctl move` DR runbook.
- **Clusters as pets, again.** — Clicking clusters up in a console "just this once" beside
  the CAPI-managed ones. *Fix:* every cluster is a `Cluster` object from a ClusterClass — no
  exceptions.
- **Raw clusters instead of a ClusterClass.** — Copy-pasting six objects per cluster, which
  drift immediately. *Fix:* author one ClusterClass with variables; make each cluster a
  short `topology`.
- **Hand-editing workload clusters.** — `kubectl edit` on a node or control-plane behind
  CAPI's back. *Fix:* change desired state in Git; let CAPI reconcile.
- **Big-bang upgrades.** — Bumping every cluster's version at once and hoping. *Fix:* canary
  one, roll waves, respect skew.
- **Shipping blank clusters.** — A new cluster with no CNI/GitOps that a human must finish,
  recreating snowflakes. *Fix:* `ClusterResourceSet` / GitOps bootstrap so it is usable on
  arrival.

## 8. Assessment

**Knowledge checks**

1. Name the three provider *kinds* in CAPI (bootstrap, control-plane, infrastructure) and
   what each is responsible for.
2. What stays the same and what changes when you move a CAPI workflow from the Docker
   provider to AWS or GCP?
3. What problem does ClusterClass solve, and what is the minimal thing you write to create a
   cluster from one?
4. Describe what CAPI does, step by step, when you change `spec.topology.version`.
5. How would you make a freshly created CAPI cluster arrive already connected to your GitOps
   source of truth?

**Concept exercise**

> Explain how a platform lets a team request, upgrade, scale, and destroy a whole Kubernetes
> cluster through reviewed pull requests, with a controller doing the work and healing drift
> — **without using the words "Cluster API," "CAPI," or "clusterctl."** Describe it purely as
> the reconciliation loop applied to clusters.

**Architecture / trade-off exercise**

> Your org already runs GKE and manages it with Terraform. A colleague proposes replacing
> that with Cluster API (CAPG). List what CAPI buys you and what it costs (another control
> plane to run and protect, provider maturity, team skill), and give the conditions under
> which each choice wins. When is "managed service + Terraform" the better platform decision?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Bootstrap turns a blank machine into a node (cloud-init + `kubeadm join`);
  control-plane manages/upgrades the API server and etcd (`KubeadmControlPlane`);
  infrastructure creates the machines, networks, and load balancers (the only cloud-specific
  part).
- **Q2:** The workflow, the top-level `Cluster` contract, the objects, and the
  upgrade/scaling mechanics stay the same; only the infrastructure provider and the
  infrastructure refs (DockerCluster → AWSCluster/GCPCluster) change.
- **Q3:** It removes per-cluster copy-paste by templating the control-plane, worker, infra,
  and bootstrap objects once with declared variables; a cluster becomes a short `Cluster`
  with `spec.topology` (class + version + replicas).
- **Q4:** It rolls a new control plane at the target version (new machines, etcd/API moved),
  then rolls each worker `MachineDeployment` — cordon, drain, replace — per surge settings,
  reconciling actual nodes to the new version.
- **Q5:** Install a GitOps agent during bootstrap (or via `ClusterResourceSet` / the Cluster
  API Add-on Provider for Flux) so the new cluster immediately pulls its desired state and
  self-configures — cluster creation triggers app delivery.
- **Trade-off:** CAPI gives one declarative, provider-portable, Kubernetes-native lifecycle
  (great across clouds or on-prem, and for many clusters), but you must run, secure, upgrade,
  and back up the management cluster and depend on provider maturity. Managed service +
  Terraform is simpler and offloads the control plane to the cloud — usually the better call
  for a single cloud and a modest cluster count. CAPI wins at fleet scale, multi-infra
  portability, or when you want cluster lifecycle inside the same GitOps/RBAC model as your
  apps.

</details>

## 9. Further reading

- The Cluster API Book — [Introduction and quick start](https://cluster-api.sigs.k8s.io/)
- Cluster API — [ClusterClass and managed topologies](https://cluster-api.sigs.k8s.io/tasks/experimental-features/cluster-class/)
- Cluster API — [Quick start with the Docker provider (CAPD)](https://cluster-api.sigs.k8s.io/user/quick-start)
- Cluster API — [`clusterctl` move and pivot](https://cluster-api.sigs.k8s.io/clusterctl/commands/move)
- Cluster API Provider GCP (CAPG) — [GKE / managed clusters](https://cluster-api-gcp.sigs.k8s.io/)
- Cluster API — [Autoscaling with the cluster-autoscaler and MachinePools](https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/autoscaling)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 19.1 — Multi-Cluster Architecture](../01-multi-cluster-architecture/) · _Next:_ [Module 19.3 — Multi-Cloud Platform Patterns →](../03-multi-cloud-platform-patterns/)
