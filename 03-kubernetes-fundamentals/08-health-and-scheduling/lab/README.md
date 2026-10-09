# Lab — Probes, placement, and safe drains

> On a three-node kind cluster you'll configure all three probes, force a **liveness**
> failure (watch a restart) and a **readiness** failure (watch a Pod leave the
> Service), reserve a node with a **taint**, then protect a spread-out Deployment with
> a **PodDisruptionBudget** and **drain a node** to see the budget hold the line. Local
> cluster only — no cloud cost.

**Estimated time:** ~60–75 minutes
**Type:** Build / debug
**Deliverable:** Notes proving how liveness, readiness, taints, and a PDB behaved,
plus a successful node drain that never dropped below the availability floor.

## Objectives

- Configure and observe liveness, readiness, and startup probes.
- Reserve a node with a taint and schedule a tolerating Pod onto it.
- Keep a service available through a node drain with a PodDisruptionBudget.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter manifests here: [`kind-config.yaml`](./kind-config.yaml),
  [`probes-deployment.yaml`](./probes-deployment.yaml),
  [`liveness-exec.yaml`](./liveness-exec.yaml), and [`pdb.yaml`](./pdb.yaml).

## Steps

1. **Create a three-node cluster.**

   ```bash
   kind create cluster --config kind-config.yaml
   kubectl get nodes
   ```

2. **Deploy the probed, spread-out app.** It sets all three probes and uses
   anti-affinity to spread replicas across nodes:

   ```bash
   kubectl apply -f probes-deployment.yaml
   kubectl rollout status deployment/web
   kubectl get pods -l app=web -o wide      # note the NODE column — replicas are spread
   ```

3. **Watch a liveness failure cause a restart.** Apply the liveness demo Pod; after
   ~30s the health file is removed, the probe fails, and the kubelet restarts the
   container:

   ```bash
   kubectl apply -f liveness-exec.yaml
   kubectl get pod liveness-demo -w          # RESTARTS climbs after ~30s; Ctrl+C
   kubectl describe pod liveness-demo | grep -A3 'Liveness'
   ```

4. **Watch a readiness failure remove a Pod from the Service.** Point the readiness
   probe at a 404 path; the Pods go `0/1 READY` and drop out of the endpoints — **but
   are not restarted**:

   ```bash
   kubectl patch deployment web --type=json \
     -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/nope"}]'
   sleep 15
   kubectl get pods -l app=web                # READY 0/1, but RESTARTS stays 0
   kubectl get endpointslices -l kubernetes.io/service-name=web -o wide   # endpoints drained
   ```

   Restore readiness and watch them return to the rotation:

   ```bash
   kubectl patch deployment web --type=json \
     -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/"}]'
   kubectl rollout status deployment/web
   kubectl get endpointslices -l kubernetes.io/service-name=web -o wide
   ```

5. **Reserve a node with a taint.** Taint one worker so ordinary Pods avoid it, then
   prove a tolerating Pod can still land there:

   ```bash
   NODE=$(kubectl get nodes -o name | grep worker | tail -1)
   kubectl taint "$NODE" tier=critical:NoSchedule --overwrite
   kubectl label "$NODE" tier=critical --overwrite

   # A plain Pod will avoid the tainted node; a tolerating one can use it:
   kubectl run tolerant --image=nginx \
     --overrides='{"spec":{"tolerations":[{"key":"tier","value":"critical","effect":"NoSchedule"}],"nodeSelector":{"tier":"critical"}}}'
   kubectl get pod tolerant -o wide           # scheduled onto the tainted node
   kubectl taint "$NODE" tier=critical:NoSchedule-    # remove the taint
   ```

6. **Protect availability with a PDB, then drain a node.** Apply the budget
   (`minAvailable: 2` of 3), then drain a worker and watch eviction respect the
   budget while Pods reschedule onto the remaining worker:

   ```bash
   kubectl apply -f pdb.yaml
   kubectl get pdb web-pdb

   DRAIN=$(kubectl get nodes -o name | grep worker | head -1)
   kubectl drain "${DRAIN#node/}" --ignore-daemonsets --delete-emptydir-data
   kubectl get pods -l app=web -o wide        # evicted Pods reappear on the other worker
   ```

   The service never dropped below 2 ready replicas. Bring the node back:

   ```bash
   kubectl uncordon "${DRAIN#node/}"
   ```

## Expected result

You configured three probes, saw liveness **restart** a wedged container and readiness
**de-route** an unready one without restarting it, reserved a node with a taint, and
drained a node while a PodDisruptionBudget kept at least two replicas serving the
whole time. That's healthy workloads plus safe, controlled placement and maintenance.

## Cleanup

> Tear the cluster down so it stops holding memory. Never skip this.

```bash
kubectl delete pod liveness-demo tolerant --ignore-not-found
kubectl delete -f pdb.yaml --ignore-not-found
kubectl delete -f probes-deployment.yaml --ignore-not-found
kind delete cluster --name pe-sched
```

## Reflection

- In step 4 the Pods went unready but were **not** restarted; in step 3 the container
  **was** restarted. Explain the design reason for that difference.
- The PDB had `minAvailable: 2` for 3 replicas. What would have happened during the
  drain if you'd set `minAvailable: 3`?
- Anti-affinity spread your replicas across nodes. Why does that matter *before* a
  node ever fails, not just during a planned drain?

## Stretch goals (optional)

- Set the readiness path to `/nope` **and** add a bad liveness path, and watch the
  difference: readiness de-routes, liveness crash-loops.
- Create two `PriorityClass` objects (low and high), fill the cluster with low-priority
  Pods, then schedule a high-priority Pod and watch it **preempt** a low one.
- Replace the anti-affinity with a `topologySpreadConstraints` block and confirm the
  replicas still spread across nodes.
