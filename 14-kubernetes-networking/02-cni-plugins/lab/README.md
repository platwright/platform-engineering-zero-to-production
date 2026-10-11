# Lab — Inspect your CNI and diagnose ContainerCreating

> You'll inspect the CNI and IPAM that a cluster is actually using, then deliberately
> break pod networking and diagnose the classic **ContainerCreating** failure —
> building the reflex that "node-wide ContainerCreating = CNI/IPAM, not the app." All
> local and free.

**Estimated time:** ~30–45 minutes
**Type:** Discovery / debug
**Deliverable:** Notes identifying your cluster's CNI config and per-node pod CIDR,
plus a root-cause for a ContainerCreating pod and the fix.

## Objectives

- Find the active CNI config and each node's IPAM pool (pod CIDR).
- Read a CNI-related failure from pod Events.
- Explain the ContainerCreating → "no IP / no CNI" chain.

## Prerequisites

- Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). No cost — all local.

## Steps

1. **Create a cluster and inspect its CNI.**

   ```bash
   kind create cluster --name cni-lab
   NODE=cni-lab-control-plane

   # The CNI config kubelet uses:
   docker exec "$NODE" ls /etc/cni/net.d
   docker exec "$NODE" sh -c 'cat /etc/cni/net.d/*'   # plugin type + IPAM
   ```

2. **See the IPAM pools (per-node pod CIDR).**

   ```bash
   kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'
   ```

   Every pod IP comes from its node's slice of the cluster pod CIDR. A `/24` per node
   caps that node at ~254 pods — this is the hard ceiling from the lesson.

3. **Deploy a pod and confirm it got an IP from that pool.**

   ```bash
   kubectl run demo --image=nginx
   kubectl get pod demo -o wide     # IP falls inside the node's podCIDR
   ```

4. **Break the CNI to reproduce ContainerCreating.** Move the CNI config aside on the
   node so the plugin can't be found, then create a pod:

   ```bash
   docker exec "$NODE" sh -c 'mkdir -p /tmp/cni-backup && mv /etc/cni/net.d/* /tmp/cni-backup/'
   kubectl run broken --image=nginx
   sleep 10
   kubectl get pod broken           # STATUS: ContainerCreating (stuck)
   ```

5. **Diagnose it the way you would in production.**

   ```bash
   kubectl describe pod broken | sed -n '/Events:/,$p'
   # Look for: "network plugin is not ready" / "failed to find plugin" /
   #           "NetworkPluginNotReady" — a CNI problem, NOT an app problem.
   ```

   The container image is fine; the pod can't get a network, so it never starts. This
   is the signature: **ContainerCreating + a CNI/network message in Events**.

6. **Fix it and watch recovery.**

   ```bash
   docker exec "$NODE" sh -c 'mv /tmp/cni-backup/* /etc/cni/net.d/'
   # kubelet retries automatically; give it a moment
   kubectl get pod broken -o wide -w
   # Ctrl-C once it reaches Running with an IP
   ```

## Expected result

- You can name the cluster's CNI plugin and show each node's pod CIDR.
- The `broken` pod sat in ContainerCreating while the CNI config was missing, with a
  network-plugin message in its Events.
- Restoring the CNI config let the pod reach Running with an IP — no app change needed.

## Cleanup

```bash
kind delete cluster --name cni-lab
```

## Reflection

- Nothing was wrong with the `nginx` image, yet the pod wouldn't start. Why does a CNI
  failure present as ContainerCreating rather than CrashLoopBackOff or ImagePullBackOff?
- If instead the *IP pool* had been exhausted (not the config missing), the symptom
  would look identical. How would you tell the two apart?
- Your cluster's CNI determines whether Module 14.3's default-deny policies are even
  possible. How would you check whether this cluster's CNI enforces NetworkPolicy?

## Stretch goals (optional)

- Recreate the cluster with Calico or Cilium instead of the default and re-run steps
  1–3 to compare the CNI config and whether NetworkPolicy is now enforceable.
- Estimate the max pods your cluster could ever schedule from the pod CIDR and the
  per-node slice size.
