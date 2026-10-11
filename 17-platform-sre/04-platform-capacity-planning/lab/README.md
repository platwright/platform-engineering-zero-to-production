# Lab — Capacity, autoscaling, and right-sizing

> You will make the capacity problem concrete on a local cluster: read node
> allocatable versus requested, provoke `Pending` pods (the signal a node autoscaler
> reacts to), validate a **Karpenter `NodePool`** with spot preference and
> consolidation, and produce a **right-sizing recommendation** from real usage.
> Karpenter's live node provisioning is a clearly-marked **cloud-optional** extension.

**Estimated time:** ~50–70 minutes (core, free/local) · +30 (optional cloud Karpenter)
**Type:** Build / analysis
**Deliverable:** A completed [`rightsizing-worksheet.md`](./rightsizing-worksheet.md)
and a validated understanding of [`karpenter-nodepool.yaml`](./karpenter-nodepool.yaml).

## Objectives

- Read a node's allocatable capacity and how much is already requested.
- Reproduce a `Pending` pod caused by insufficient capacity.
- Explain spot preference and consolidation in a Karpenter `NodePool`.
- Compute a right-sizing recommendation from actual usage versus requests.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, [kind](https://kind.sigs.k8s.io/), and `kubectl`.
- [Module 17.4](../README.md) theory.
- Starter files in this folder:
  [`karpenter-nodepool.yaml`](./karpenter-nodepool.yaml) and
  [`rightsizing-worksheet.md`](./rightsizing-worksheet.md).
- The optional cloud extension needs an EKS cluster and will incur cost — see its note.

## Steps

1. **Create a cluster and install metrics-server.** metrics-server powers
   `kubectl top`, which you need for right-sizing:

   ```bash
   kind create cluster --name pe-capacity
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   # kind's kubelet serving cert is self-signed; let metrics-server accept it
   kubectl -n kube-system patch deployment metrics-server --type=json \
     -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   kubectl -n kube-system rollout status deploy/metrics-server --timeout=120s
   ```

2. **Read the capacity ledger.** See how much the node can schedule and how much is
   already reserved by requests:

   ```bash
   kubectl describe node | grep -A6 "Allocated resources"
   kubectl get node -o jsonpath='{.items[0].status.allocatable.cpu}{"\n"}{.items[0].status.allocatable.memory}{"\n"}'
   ```

   Note the scheduler cares about **requests** against this allocatable total, not live
   usage.

3. **Provoke a `Pending` pod.** Ask for more than any kind node can provide — the exact
   condition that makes a node autoscaler add capacity:

   ```bash
   kubectl create deployment hog --image=registry.k8s.io/pause:3.9
   kubectl set resources deployment/hog --requests=memory=256Gi
   kubectl get pods -l app=hog
   kubectl describe pod -l app=hog | grep -A3 Events
   # expect: Pending — "Insufficient memory" / "0/1 nodes are available"
   ```

   On a managed cluster, Karpenter would read this pending pod and launch a right-sized,
   spot-preferring node to fit it. Clean up the hog: `kubectl delete deploy hog`.

4. **Validate the Karpenter NodePool.** You cannot run Karpenter on kind (no cloud
   provider), but you can confirm the manifest parses and read how it encodes the two
   key behaviors:

   ```bash
   kubectl apply --dry-run=client -f karpenter-nodepool.yaml
   ```

   In [`karpenter-nodepool.yaml`](./karpenter-nodepool.yaml), find:

   - **Spot preference** — `karpenter.sh/capacity-type: In ["spot", "on-demand"]`
     lets Karpenter pick cheap spot first and fall back to on-demand.
   - **Consolidation** — `disruption.consolidationPolicy: WhenEmptyOrUnderutilized`
     with `consolidateAfter` removes empty nodes and repacks underused ones.
   - **Right-sizing room** — the `instance-category` range lets Karpenter choose the
     cheapest shape that fits the pods, instead of a single fixed node size.

5. **Deploy an over-provisioned workload.** Simulate a team that requested far more
   than it uses:

   ```bash
   kubectl create deployment overshoot --image=registry.k8s.io/pause:3.9 --replicas=3
   kubectl set resources deployment/overshoot --requests=cpu=500m,memory=512Mi
   kubectl rollout status deploy/overshoot --timeout=60s
   sleep 60   # let metrics-server collect samples
   ```

   The `pause` container uses almost nothing, so this models a classic request-versus-
   usage gap.

6. **Measure usage versus requests and recommend.** Compare actual usage to the
   requests, then fill in [`rightsizing-worksheet.md`](./rightsizing-worksheet.md):

   ```bash
   kubectl top pods --containers -l app=overshoot
   # requests were cpu=500m, mem=512Mi; actual is tiny → massively over-provisioned
   ```

   Compute a recommendation of roughly **p95 usage + headroom** and record the reclaimed
   capacity. (A real right-sizing uses 30 days of Prometheus data and would use VPA in
   recommend mode; here the gap is obvious from a single reading.)

7. **(Optional, cloud — has cost) Watch Karpenter provision live.** On a real EKS
   cluster with Karpenter installed, apply the NodePool and scale a workload to force
   provisioning:

   ```bash
   # COST WARNING: this launches real EC2 instances and requires an AWS account,
   # an EKS cluster, and Karpenter installed. Delete everything when done.
   kubectl apply -f karpenter-nodepool.yaml
   kubectl scale deploy/overshoot --replicas=30
   kubectl get nodeclaims -w          # Karpenter creates a right-sized (likely spot) node
   kubectl scale deploy/overshoot --replicas=1
   # after consolidateAfter, Karpenter removes/repacks the now-idle node
   kubectl get nodeclaims -w
   ```

## Expected result

You can state your node's allocatable capacity and how much is requested; the `hog`
pod sits `Pending` with an "Insufficient memory" event; `kubectl apply --dry-run` on
the NodePool succeeds and you can point to the lines that implement spot preference and
consolidation; and your worksheet shows the `overshoot` workload using a fraction of
its requests with a recommendation that reclaims most of them. In the optional cloud
extension, a NodeClaim appears when you scale up and disappears after consolidation.

## Cleanup

> Tear down everything. If you ran the cloud extension, double-check no nodes remain.

```bash
kind delete cluster --name pe-capacity
# cloud extension only:
# kubectl delete -f karpenter-nodepool.yaml
# kubectl delete deploy overshoot
# confirm no Karpenter-made nodes are left:  kubectl get nodeclaims
```

## Reflection

- The scheduler left your pod `Pending` based on **requests**, while the node had
  plenty of free *usage* headroom. Why is that the correct behavior, and what does it
  imply for setting requests?
- Karpenter consolidation saves money by moving pods around. Which of your workloads
  would you protect from that churn, and how?
- Your `overshoot` workload reclaimed most of its requested capacity. Multiply that
  across a platform of hundreds of services — why is right-sizing the highest-leverage
  cost lever a platform team has?

## Stretch goals (optional)

- Add an **HPA** to `overshoot` (`kubectl autoscale deploy/overshoot --cpu-percent=50
  --min=1 --max=10`), drive CPU, and watch replicas scale — then reason about why you
  would *not* also run VPA on CPU for the same workload.
- Write a second Karpenter `NodePool` for a **spot-only batch** pool with a taint, and
  describe which workloads you would steer to it.
- Turn the worksheet into a tiny script that reads `kubectl top` and prints a
  recommended request per container at p95 + 30% headroom.
