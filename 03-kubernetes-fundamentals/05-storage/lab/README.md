# Lab — Persistent data that survives Pods

> You'll dynamically provision storage with the default StorageClass, prove that data
> written by one Pod survives that Pod's deletion, then run a StatefulSet where each
> replica owns a durable volume it reattaches to by stable name. You'll also inspect
> why kind's local storage can't be expanded while GKE's can. Local kind cluster only.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A StatefulSet whose per-replica data survives Pod deletion, plus
notes on dynamic provisioning, `WaitForFirstConsumer`, and volume expansion.

## Objectives

- Dynamically provision a PV via a PVC and the default StorageClass.
- Prove data persists across Pod deletion and recreation.
- See per-replica PVCs for a StatefulSet and that they survive the StatefulSet.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter manifests here: [`pvc.yaml`](./pvc.yaml), [`pod.yaml`](./pod.yaml),
  [`statefulset-pvc.yaml`](./statefulset-pvc.yaml), and the GKE reference
  [`gke-storageclass.yaml`](./gke-storageclass.yaml).

## Steps

1. **Create a cluster and inspect the default StorageClass.**

   ```bash
   kind create cluster --name pe-storage
   kubectl get storageclass
   kubectl get storageclass standard -o jsonpath='{.provisioner}{"  expandable="}{.allowVolumeExpansion}{"  bind="}{.volumeBindingMode}{"\n"}'
   ```

   kind's default is `standard` (local-path), with `volumeBindingMode:
   WaitForFirstConsumer` and no volume expansion.

2. **Create a claim and watch `WaitForFirstConsumer`.** Apply the standalone PVC and
   note it stays `Pending` — the disk isn't created until a Pod consumes it:

   ```bash
   kubectl apply -f pvc.yaml
   kubectl get pvc demo-data          # STATUS: Pending (waiting for first consumer)
   kubectl describe pvc demo-data | grep -A2 Events
   ```

3. **Consume the claim and watch it bind.** Apply the Pod; now the provisioner
   creates a PV and binds it:

   ```bash
   kubectl apply -f pod.yaml
   kubectl wait --for=condition=Ready pod/writer --timeout=60s
   kubectl get pvc demo-data          # STATUS: Bound
   kubectl get pv                     # a PV was dynamically created
   ```

4. **Write data to the volume.**

   ```bash
   kubectl exec writer -- sh -c 'echo "persisted-at-$(date +%s)" > /data/msg'
   kubectl exec writer -- cat /data/msg
   ```

5. **Destroy the Pod and prove the data survives.** Delete the Pod, recreate it
   (same PVC), and read the file back:

   ```bash
   kubectl delete pod writer
   kubectl apply -f pod.yaml
   kubectl wait --for=condition=Ready pod/writer --timeout=60s
   kubectl exec writer -- cat /data/msg     # SAME message — the Pod changed, data didn't
   ```

6. **Deploy a StatefulSet with per-replica storage.** Each replica gets its own PVC
   from the `volumeClaimTemplate`:

   ```bash
   kubectl apply -f statefulset-pvc.yaml
   kubectl rollout status statefulset/datastore
   kubectl get pvc -l app=datastore         # data-datastore-0 and data-datastore-1
   ```

   Write a **different** value into each replica's volume:

   ```bash
   kubectl exec datastore-0 -- sh -c 'echo "I am shard 0" > /data/id'
   kubectl exec datastore-1 -- sh -c 'echo "I am shard 1" > /data/id'
   ```

7. **Prove stable identity + durable storage.** Delete `datastore-0`; it returns with
   the **same name** and **its own** data:

   ```bash
   kubectl delete pod datastore-0
   kubectl wait --for=condition=Ready pod/datastore-0 --timeout=90s
   kubectl exec datastore-0 -- cat /data/id     # "I am shard 0" — reattached to data-datastore-0
   ```

8. **Inspect volume expansion (and why it's GKE-only here).** Try to grow the
   StatefulSet's PVC; kind's local-path class rejects it:

   ```bash
   kubectl get storageclass standard -o jsonpath='{.allowVolumeExpansion}{"\n"}'   # (empty/false)
   kubectl patch pvc data-datastore-0 -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}' || true
   ```

   On GKE you'd first apply an expandable class like
   [`gke-storageclass.yaml`](./gke-storageclass.yaml) (`allowVolumeExpansion: true`),
   and the same `kubectl patch` would grow the disk **online**, with no Pod restart.

## Expected result

A PVC that bound only once a Pod consumed it, data that survived Pod deletion, a
StatefulSet whose replicas kept their own durable volumes across rescheduling, and a
clear picture of when volume expansion is possible. You've seen stateless
orchestration safely manage stateful data.

## Cleanup

> Important: a StatefulSet's PVCs are **retained** on purpose, so you must delete them
> explicitly or the backing storage lingers. Then delete the cluster. Never skip this.

```bash
kubectl delete pod writer --ignore-not-found
kubectl delete -f statefulset-pvc.yaml --ignore-not-found
kubectl delete pvc --all               # remove the retained PVCs (data-datastore-*, demo-data)
kind delete cluster --name pe-storage
```

## Reflection

- In step 2 the PVC stayed `Pending` until a Pod used it. What problem does
  `WaitForFirstConsumer` solve in a multi-zone cluster?
- You deleted `datastore-0` and it came back with its original data. Trace the chain:
  Pod → PVC → PV. Which links stayed constant?
- Deleting the StatefulSet left its PVCs behind. Why is that the safe default, and why
  is it also a cost trap?

## Stretch goals (optional)

- Set the StatefulSet replicas to 1 (`kubectl scale statefulset datastore
  --replicas=1`) and confirm `data-datastore-1` is **not** deleted — scale-down keeps
  the PVC.
- Delete only `data-datastore-1` and scale back to 2; watch a fresh empty volume get
  provisioned for the new `datastore-1`.
- Read `kubectl get pv -o wide` and map each PV back to the PVC and Pod that claims
  it.
