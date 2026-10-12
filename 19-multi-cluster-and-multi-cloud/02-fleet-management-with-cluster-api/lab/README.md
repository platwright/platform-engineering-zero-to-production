# Lab — Clusters as code with CAPD

> You'll turn a kind cluster into a **Cluster API management cluster**, install CAPI with
> the local **Docker (CAPD) provider**, and create a **workload cluster from a
> ClusterClass** — a real reconcile loop building a real cluster out of containers, for
> free. You'll feel that a fresh CAPI cluster is *blank* (no CNI → `NotReady`), fix it,
> run a workload, then **scale** and **upgrade** the cluster by changing one field. GKE
> via CAPG appears only as an optional reference.

**Estimated time:** ~75–110 minutes (plus wait time while machines provision)
**Type:** Build
**Deliverable:** A workload cluster created and managed declaratively by Cluster API from
a ClusterClass, scaled and (optionally) upgraded by editing its spec.

## Objectives

- Bootstrap a management cluster and install CAPI with the Docker provider.
- Create a workload cluster from a **ClusterClass** topology.
- Retrieve its kubeconfig, install a CNI, and run a workload.
- **Scale** worker nodes declaratively; **upgrade** the cluster by changing its version.
- Read how the same workflow maps to GKE (CAPG), without running it.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker (ideally 8 GB+ free RAM for the management cluster plus CAPD node containers),
  `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- The [`clusterctl` CLI](https://cluster-api.sigs.k8s.io/user/quick-start) on your `PATH`.
- Linux or WSL2 recommended (CAPD mounts the host Docker socket).
- Starter files: [`capi-mgmt.yaml`](./capi-mgmt.yaml), [`clusterclass.yaml`](./clusterclass.yaml),
  [`workload-cluster.yaml`](./workload-cluster.yaml), and
  [`capg-gke-cluster.optional.yaml`](./capg-gke-cluster.optional.yaml).

> **Version note.** Cluster API moves fast. The guaranteed, version-correct manifests in
> this lab come from `clusterctl generate` — it fetches templates matching the provider
> version you installed. The provided [`clusterclass.yaml`](./clusterclass.yaml) and
> [`workload-cluster.yaml`](./workload-cluster.yaml) mirror that output so you can read and
> reuse it; if a field is rejected by your version, trust the `clusterctl`-generated file.

## Steps

### Part 1 — a management cluster with Cluster API

1. **Create the management cluster.** CAPD builds workload nodes as Docker containers, so
   the management cluster must see the host Docker socket — that is what
   [`capi-mgmt.yaml`](./capi-mgmt.yaml) mounts:

   ```bash
   kind create cluster --name capi-mgmt --config capi-mgmt.yaml
   kubectl cluster-info --context kind-capi-mgmt
   ```

2. **Install Cluster API with the Docker provider.** `CLUSTER_TOPOLOGY=true` enables the
   ClusterClass feature you'll use:

   ```bash
   export CLUSTER_TOPOLOGY=true
   clusterctl init --infrastructure docker
   kubectl get pods -A | grep capi    # bootstrap, control-plane, infrastructure controllers
   ```

   Your kind cluster is now a **control plane for other clusters**.

### Part 2 — a workload cluster from a ClusterClass

1. **Generate the version-correct manifests.** This produces a `ClusterClass` named
   `quick-start` plus a `Cluster` that references it with a tiny `spec.topology`:

   ```bash
   clusterctl generate cluster pe-dev --flavor development \
     --kubernetes-version v1.31.2 \
     --control-plane-machine-count 1 \
     --worker-machine-count 1 \
     > pe-dev.yaml
   ```

   Open `pe-dev.yaml` and compare it to [`clusterclass.yaml`](./clusterclass.yaml) (the
   templates authored once) and [`workload-cluster.yaml`](./workload-cluster.yaml) (how
   little the `Cluster` itself is). Same shapes — one is just version-matched for you.

2. **Apply it and watch the cluster get built.**

   ```bash
   kubectl apply -f pe-dev.yaml
   clusterctl describe cluster pe-dev        # re-run to watch it progress
   kubectl get machines                      # control-plane + worker Machines appear
   ```

   A controller is provisioning machines and bootstrapping Kubernetes onto them — no SSH,
   no console. Wait until the control plane reports initialized:

   ```bash
   kubectl get kubeadmcontrolplane
   ```

3. **Pull the workload cluster's kubeconfig and see it's blank.**

   ```bash
   clusterctl get kubeconfig pe-dev > pe-dev.kubeconfig
   kubectl --kubeconfig pe-dev.kubeconfig get nodes
   ```

   Nodes are `NotReady` — a fresh CAPI cluster has **no CNI**. This is the lesson's
   "bootstrap to production-ready" point made physical: creation and configuration are
   separate loops.

4. **Install a CNI, then confirm the nodes go Ready.**

   ```bash
   kubectl --kubeconfig pe-dev.kubeconfig apply -f \
     https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/calico.yaml
   kubectl --kubeconfig pe-dev.kubeconfig get nodes -w    # Ctrl+C once Ready
   ```

5. **Run a workload on your CAPI-built cluster.**

   ```bash
   kubectl --kubeconfig pe-dev.kubeconfig create deployment hello --image=nginx:1.27
   kubectl --kubeconfig pe-dev.kubeconfig get pods -w      # Ctrl+C once Running
   ```

   You deployed to a cluster that did not exist fifteen minutes ago and was created
   entirely from declarative objects.

### Part 3 — change the cluster by changing its spec

1. **Scale the worker pool declaratively.** The cluster is topology-managed, so you edit
   its `spec.topology` rather than scaling a Deployment:

   ```bash
   kubectl patch cluster pe-dev --type merge -p \
     '{"spec":{"topology":{"workers":{"machineDeployments":[{"class":"default-worker","name":"md-0","replicas":2}]}}}}'
   kubectl get machines -w        # a new worker Machine is provisioned; Ctrl+C when done
   ```

2. **(Optional, slow) Upgrade the cluster by changing one field.** Bump the Kubernetes
   version and watch CAPI roll the control plane and workers:

   ```bash
   kubectl patch cluster pe-dev --type merge -p \
     '{"spec":{"topology":{"version":"v1.32.0"}}}'
   clusterctl describe cluster pe-dev    # re-run to watch the rolling replacement
   ```

   New machines come up at the new version and old ones are drained and removed — a
   declarative, auditable, rolling upgrade. This takes several minutes on CAPD; skip it if
   you are low on resources.

3. **(Optional) Stamp a second cluster from the same ClusterClass.** This is the
   reproducibility payoff — a whole cluster in a dozen lines, reusing `quick-start`:

   ```bash
   kubectl apply -f workload-cluster.yaml    # references class: quick-start
   kubectl get clusters
   ```

   Skip this if RAM is tight; delete it in cleanup if you created it.

4. **(Optional, cloud) Read the GKE reference.** Open
   [`capg-gke-cluster.optional.yaml`](./capg-gke-cluster.optional.yaml). It shows the *same*
   top-level `Cluster` contract targeting **CAPG/GKE** instead of Docker — only the
   infrastructure and control-plane refs change. Running it needs a GCP project, billing,
   and `clusterctl init --infrastructure gcp`, so it stays a read-only reference here.

## Expected result

- `kubectl get machines` shows a control-plane Machine and (after scaling) two worker
  Machines, all `Running`.
- `clusterctl describe cluster pe-dev` shows the cluster healthy and, if you upgraded,
  machines at the new version.
- `kubectl --kubeconfig pe-dev.kubeconfig get nodes` shows `Ready` nodes after the CNI,
  and your `hello` Deployment runs on them.
- You can explain why the cluster was `NotReady` before the CNI, and why a `Cluster` with
  a `topology` is all it takes to define one.

## Cleanup

> Delete the workload `Cluster` objects **first** so CAPI tears down their node containers,
> then delete the management kind cluster. Never skip this — stray CAPD containers leak RAM.

```bash
kubectl delete cluster pe-dev --ignore-not-found
kubectl delete -f workload-cluster.yaml --ignore-not-found   # only if you created it
kubectl get machines        # wait until empty (containers are being removed)
rm -f pe-dev.yaml pe-dev.kubeconfig
kind delete cluster --name capi-mgmt
docker ps | grep pe-        # should be empty; if not, docker rm -f the leftovers
```

## Reflection

- You installed the CNI by hand and the node went `Ready`. Which CAPI mechanism
  (`ClusterResourceSet`, a GitOps agent) would make a new cluster arrive with a CNI and the
  platform's apps already present — and why does that matter at fleet scale?
- Scaling and upgrading were both "edit the spec, let the controller act." What does that
  give you over `kubeadm upgrade` on each node, in terms of audit and rollback?
- The GKE reference changed only the infrastructure refs. What does that portability buy a
  platform team, and what does CAPI *cost* you that a managed GKE + Terraform setup does not?

## Stretch goals (optional)

- Author a tiny `ClusterResourceSet` that labels-targets your cluster and installs the CNI
  automatically, so the next cluster is never `NotReady`.
- Add a second `machineDeployment` class to the ClusterClass (e.g. a `spot-worker`) and give
  `pe-dev` a pool of each.
- Install an ArgoCD agent on the new cluster and register it with a management-cluster
  ArgoCD (reuse Module 19.1), so cluster creation hands off to GitOps.
- Follow the [CAPG quick start](https://cluster-api-gcp.sigs.k8s.io/) on a throwaway GCP
  project to create a real GKE cluster from the same `Cluster` contract (**costs money** —
  delete it immediately after).
