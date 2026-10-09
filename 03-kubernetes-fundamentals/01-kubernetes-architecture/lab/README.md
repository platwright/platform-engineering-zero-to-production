# Lab — Explore a cluster and the reconciliation loop

> You'll stand up a local multi-node Kubernetes cluster with kind, find the
> control-plane components running inside it, and then provoke the reconciliation
> loop — deleting Pods and watching the system heal (or not) depending on whether a
> controller owns them. Everything runs on your laptop; there is no cloud cost.

**Estimated time:** ~45–60 minutes
**Type:** Discovery
**Deliverable:** A running three-node kind cluster you have explored, plus notes on
what each control-plane component does and how reconciliation behaved.

## Objectives

- Create and inspect a multi-node cluster.
- Locate the API server, etcd, scheduler, and controller manager as real Pods.
- Observe the difference between a bare Pod and a Pod owned by a controller.
- Read the `spec` vs `status` of an object.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/) installed.
- The starter file [`kind-config.yaml`](./kind-config.yaml) in this folder.

## Steps

1. **Create a three-node cluster.** From this `lab/` directory, create the cluster
   defined by the starter config (one control-plane node, two workers):

   ```bash
   kind create cluster --config kind-config.yaml
   ```

   kind builds the nodes as containers and writes a `kind-pe-k8s` context into your
   kubeconfig. Confirm the nodes and your context:

   ```bash
   kubectl config current-context      # → kind-pe-k8s
   kubectl get nodes -o wide
   ```

   You should see three nodes: one with the `control-plane` role and two workers.

2. **Find the control plane.** The control-plane components run as Pods in the
   `kube-system` namespace. List them and pick out the ones from the lesson:

   ```bash
   kubectl get pods -n kube-system
   ```

   Look for `kube-apiserver-*`, `etcd-*`, `kube-scheduler-*`, and
   `kube-controller-manager-*` (all pinned to the control-plane node), plus a
   `kube-proxy-*` on every node and the CNI (`kindnet-*`) networking Pods.

3. **Confirm the data-plane agents.** The kubelet isn't a Pod — it runs on the node
   itself. Inspect a node and read its reported component versions and conditions:

   ```bash
   kubectl describe node pe-k8s-worker | sed -n '/System Info/,/Non-terminated/p'
   ```

   Note the `Kubelet Version` and `Container Runtime Version` (containerd).

4. **See reconciliation NOT happen (a bare Pod).** Create a single Pod with no
   controller, then delete it:

   ```bash
   kubectl run nginx --image=nginx
   kubectl get pod nginx            # Running
   kubectl delete pod nginx
   kubectl get pod nginx            # NotFound — nothing brings it back
   ```

   Nothing reconciles a bare Pod's existence, so it stays gone.

5. **See reconciliation happen (a controller).** Now create a Deployment, which
   declares a desired replica count, and delete one of its Pods:

   ```bash
   kubectl create deployment web --image=nginx --replicas=3
   kubectl get pods -l app=web
   ```

   In one terminal, watch the Pods; in another, delete one:

   ```bash
   kubectl get pods -l app=web -w          # terminal A: keep this running
   ```

   ```bash
   kubectl delete pod -l app=web \
     --field-selector=status.phase=Running --wait=false | head -n1   # terminal B
   ```

   In terminal A you'll see a Pod go `Terminating` and a brand-new Pod appear within
   seconds. The Deployment's controller noticed actual (2) ≠ desired (3) and acted.

6. **Read desired vs actual state.** Look at the object that drove step 5:

   ```bash
   kubectl get deployment web -o jsonpath='{.spec.replicas}{"\n"}'          # desired
   kubectl get deployment web -o jsonpath='{.status.readyReplicas}{"\n"}'   # actual
   ```

   You set `spec.replicas`; the controller wrote `status.readyReplicas`. That split
   is the reconciliation loop expressed as data.

7. **(Optional) Watch the whole system settle.** Scale up and watch the gap close in
   real time:

   ```bash
   kubectl scale deployment web --replicas=5
   kubectl get pods -l app=web -w      # Ctrl+C once five are Running
   ```

## Expected result

You can point to the API server, etcd, scheduler, and controller-manager Pods in
`kube-system`; you observed a bare Pod stay deleted while a controller-owned Pod was
replaced automatically; and you can name which field is desired state (`spec`) and
which is actual state (`status`). That is the reconciliation loop, observed
end-to-end.

## Cleanup

> Always tear the cluster down — it holds several containers open and consumes
> laptop memory. Never skip this.

```bash
kubectl delete deployment web --ignore-not-found
kind delete cluster --name pe-k8s
```

Confirm it's gone:

```bash
kind get clusters      # pe-k8s should no longer be listed
```

## Reflection

- When you deleted the controller-owned Pod, *nothing* told the kubelet "make a new
  Pod." Trace what actually happened in terms of the API server, the controller, the
  scheduler, and the kubelet. Who watched what?
- A bare Pod stayed deleted; a Deployment's Pod came back. In your own words, why is
  "create a controller, not a Pod" the right default?
- You never edited `status`. Why would hand-editing it be meaningless?

## Stretch goals (optional)

- Run `kubectl get events -n default --sort-by=.lastTimestamp` after step 5 and find
  the scheduler and kubelet events for the replacement Pod.
- Delete the `kube-scheduler` static Pod's mirror
  (`kubectl delete pod -n kube-system kube-scheduler-pe-k8s-control-plane`) and
  watch the kubelet recreate it from its static manifest — reconciliation at the
  node level.
- Add a third worker by editing `kind-config.yaml`, recreate the cluster, and
  confirm Pods spread across the new node.
