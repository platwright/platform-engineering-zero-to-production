# Module 03.5 — Storage

> Kubernetes schedules Pods anywhere and replaces them freely — so how does a
> database keep its data when its Pod is destroyed and recreated on another node? The
> answer is the **PersistentVolume / PersistentVolumeClaim** abstraction plus
> **dynamic provisioning**. This module explains how stateless orchestration manages
> stateful data from first principles.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 03.2](../02-workloads/) (StatefulSets) and a working
`kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain the **claim-check** model: how a **PVC** (request) binds to a **PV**
  (storage) and why that decoupling exists.
- Use a **StorageClass** for **dynamic provisioning** instead of hand-creating
  volumes.
- Choose the right **access mode** (`ReadWriteOnce`, `ReadOnlyMany`,
  `ReadWriteMany`, `ReadWriteOncePod`).
- Describe the **CSI** plugin model and the role of `allowVolumeExpansion`.
- Explain how a **StatefulSet** gives each replica its own durable volume that
  survives rescheduling.

---

## 1. Concept

### The problem: Pods are disposable, data must not be

Everything so far has been stateless: kill a Pod, a new identical one takes its
place, and nobody cares. Stateful workloads (databases, queues, anything that writes
to disk) break that assumption. A container's own filesystem is **ephemeral** — it's
gone when the container dies. You need storage whose lifecycle is **independent of
any Pod**, that can detach from a dying Pod and reattach to its replacement.

### The claim-check model: PV and PVC

Kubernetes decouples *who needs storage* from *what storage exists*, like a coat
check:

- A **PersistentVolume (PV)** is an actual piece of storage in the cluster (a cloud
  disk, an NFS export, a local path). It's a cluster resource, like a node — it
  exists independently of any Pod.
- A **PersistentVolumeClaim (PVC)** is a *request* for storage by a workload: "I need
  10Gi, ReadWriteOnce." It's the **claim-check ticket**.

Kubernetes **binds** a PVC to a suitable PV. The Pod references the *PVC* (the
ticket), never the PV directly. When the Pod is rescheduled, it still references the
same PVC, which is still bound to the same PV — so the data follows the workload.

```text
   Pod  ──references──►  PVC (ticket: "10Gi RWO")  ──bound to──►  PV (the real disk)
   (disposable)          (outlives the Pod)                        (outlives the Pod)
```

This indirection is why a database Pod can die and its replacement comes back with
all its data: the Pod changed, the PVC→PV binding didn't.

### Dynamic provisioning with StorageClasses

Hand-creating a PV for every claim doesn't scale. A **StorageClass** automates it:
it names a **provisioner** (a CSI driver) and parameters (disk type, replication).
When a PVC asks for a StorageClass, the provisioner **creates a matching PV on
demand** and binds it. This is **dynamic provisioning** — the normal path in every
real cluster.

- A cluster usually has a **default StorageClass** (on kind it's `standard`, backed
  by a local-path provisioner; on GKE it's a PD-backed class).
- `volumeBindingMode: WaitForFirstConsumer` delays creating the disk until a Pod is
  scheduled, so the disk lands in the **same zone** as the Pod — important in
  multi-zone clusters.
- `reclaimPolicy` decides what happens to the PV when the PVC is deleted: `Delete`
  (destroy the disk) or `Retain` (keep it for manual recovery).

### Access modes — and what they really mean

An access mode describes how many nodes can mount a volume, not how many Pods:

- **ReadWriteOnce (RWO)** — mounted read-write by a single **node** (the most common;
  cloud block disks are RWO). Multiple Pods on that *same* node can share it.
- **ReadWriteOncePod (RWOP)** — read-write by exactly **one Pod**, cluster-wide. The
  strict choice for "only one writer, ever."
- **ReadOnlyMany (ROX)** — read-only by many nodes.
- **ReadWriteMany (RWX)** — read-write by many nodes at once. Requires a shared
  filesystem (NFS, CephFS, Filestore); ordinary cloud block storage **cannot** do
  this.

Choosing RWX "to be safe" when you only have block storage is a classic mistake —
the PVC will never bind.

### CSI: the storage plugin interface

The **Container Storage Interface (CSI)** is the standard that lets any storage
vendor plug into Kubernetes without changing Kubernetes itself. A CSI driver
(installed as Pods, often a DaemonSet + controller) knows how to provision, attach,
mount, snapshot, and expand its kind of storage. "GKE Persistent Disk," "EBS," and
kind's local-path are all CSI (or CSI-like) drivers behind a StorageClass.

### Volume expansion

Need a bigger disk? If the StorageClass has `allowVolumeExpansion: true`, you can
**edit the PVC's requested size** and the CSI driver grows the volume (often online,
no downtime). If it's `false` (as with kind's default local-path), expansion is
rejected — you'd have to migrate data. Always check the StorageClass before promising
"we can just grow it."

### StatefulSet storage patterns

A StatefulSet's `volumeClaimTemplate` creates **one PVC per replica**, named stably
(`data-web-0`, `data-web-1`, …). Pod `web-0` always reattaches to `data-web-0`. And
by design, **deleting the StatefulSet does not delete the PVCs** — your data survives
an accidental `delete`, which is safe but also a cleanup footgun.

---

## 2. Why it matters for platform engineering

- **Data safety is the highest-stakes platform responsibility.** A bad reclaim policy
  or a wrong access mode can destroy or strand customer data. The storage defaults
  *you* set protect every team that runs something stateful.
- **StorageClasses are a platform product surface.** Teams shouldn't reason about CSI
  drivers and zones; they should pick from `fast-ssd`, `standard`, or `backup` classes
  you curate, with sane reclaim and binding modes baked in.
- **Cost lives here.** Over-provisioned, never-reclaimed volumes are a top cloud
  waste line. Default classes, expansion policy, and orphaned-PVC cleanup are
  FinOps levers ([Phase 18](../../18-finops-and-cost-engineering/)).
- **"Can we run the database on Kubernetes?" is a storage question.** Answering it
  well requires understanding access modes, binding, and the data-survival
  guarantees above.

---

## 3. Mental model

Storage is a **coat check**: you hand over a ticket (PVC), the attendant finds or
makes a matching coat (PV via StorageClass), and no matter who comes back to the
counter (which Pod), the same ticket retrieves the same coat.

```text
   StatefulSet "db"
     ├── Pod db-0 ──► PVC data-db-0 ──► PV (10Gi disk A)   ← same binding
     ├── Pod db-1 ──► PVC data-db-1 ──► PV (10Gi disk B)     survives Pod
     └── Pod db-2 ──► PVC data-db-2 ──► PV (10Gi disk C)     reschedules

   StorageClass "standard"  (provisioner + reclaimPolicy + allowVolumeExpansion)
        creates a PV on demand whenever a PVC asks for it (dynamic provisioning)
```

Rules to remember:

1. **Pods reference PVCs, never PVs.** The ticket outlives the holder.
2. **The StorageClass makes storage on demand.** You rarely create PVs by hand.
3. **Access mode is about nodes, and RWX needs a shared filesystem.** Block storage
   is RWO.

---

## 4. Minimal implementation

Prove the core guarantee: data outlives the Pod. First claim some storage — the
default StorageClass dynamically provisions a PV and binds it:

```bash
kubectl get storageclass          # note the (default) class, e.g. "standard"
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: demo-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
EOF
kubectl get pvc demo-data          # STATUS Bound → a PV was created for it
```

Mount it in a Pod and write data:

```bash
kubectl run writer --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"c","image":"busybox:1.36","command":["sh","-c","echo persisted-at-$(date +%s) > /data/msg; sleep 3600"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"demo-data"}}]}}'
kubectl exec writer -- cat /data/msg     # your message
```

Now destroy the Pod and bring a new one back to the **same PVC** — the data is still
there:

```bash
kubectl delete pod writer
kubectl run reader --image=busybox:1.36 --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"c","image":"busybox:1.36","command":["sh","-c","cat /data/msg; sleep 3600"],"volumeMounts":[{"name":"d","mountPath":"/data"}]}],"volumes":[{"name":"d","persistentVolumeClaim":{"claimName":"demo-data"}}]}}'
kubectl exec reader -- cat /data/msg     # SAME message — the Pod changed, the data didn't
```

The container filesystem was ephemeral; the PVC-bound volume was not.

---

## 5. Hands-on lab

You'll use the default StorageClass to dynamically provision storage, prove data
survives Pod deletion, then deploy a StatefulSet whose each replica gets its own
durable volume that reattaches by stable name. You'll also inspect
`allowVolumeExpansion` and see why kind's local storage can't grow (while GKE's can).

➡️ **[Start the lab: Persistent data that survives Pods](./lab/README.md)**

---

## 6. Production considerations

- **Set reclaim policy deliberately.** `Delete` is convenient but unforgiving;
  critical data often warrants `Retain` plus a documented recovery process so a
  deleted PVC doesn't vaporize the disk.
- **Use `WaitForFirstConsumer` in multi-zone clusters.** Otherwise a disk may be
  created in a different zone than the Pod that needs it, and the Pod can't schedule.
- **Back up with volume snapshots.** CSI snapshots (`VolumeSnapshot`) are your
  point-in-time recovery; "it's on a PV" is not a backup.
- **Right-size and allow expansion.** Start smaller with `allowVolumeExpansion: true`
  and grow on demand rather than over-provisioning every volume up front.
- **Clean up orphaned PVCs.** StatefulSet scale-down and deletions leave PVCs behind
  by design; track and reclaim them or pay for idle disks forever.
- **Prefer managed data services when you can.** Running a correct, backed-up,
  highly-available database on Kubernetes is real work; a managed database is often
  the better platform choice. Offer both, and be honest about the trade-off.

---

## 7. Common mistakes

- **Requesting `ReadWriteMany` on block storage.** — Cloud block disks are RWO, so an
  RWX PVC never binds and the Pod stays `Pending`. *Fix:* use RWO (one node) or a
  real shared filesystem (NFS/Filestore/CephFS) for RWX.
- **Assuming a PV is a backup.** — A single disk fails or gets deleted with the PVC.
  *Fix:* take CSI volume snapshots and test restores.
- **`reclaimPolicy: Delete` on precious data.** — Deleting the PVC (or StatefulSet
  cleanup) destroys the disk. *Fix:* `Retain` for critical volumes; document
  recovery.
- **Expecting to shrink or freely expand volumes.** — You can usually grow (if the
  class allows) but **not shrink**, and some classes don't allow expansion at all.
  *Fix:* check `allowVolumeExpansion`; plan sizes.
- **Forgetting StatefulSet PVCs persist.** — You delete the StatefulSet and are
  surprised disks (and bills) remain. *Fix:* explicitly delete the leftover PVCs when
  you truly want the data gone.

---

## 8. Assessment

**Knowledge checks**

1. What's the difference between a PV and a PVC, and why does a Pod reference the PVC
   rather than the PV?
2. What does a StorageClass do, and what is "dynamic provisioning"?
3. Why can't you use `ReadWriteMany` with an ordinary cloud block disk?
4. What happens to a StatefulSet's PVCs when you delete the StatefulSet?
5. How do you grow a volume, and what must be true of its StorageClass?

**Concept exercise**

> Explain how a database keeps all its data after its Pod is deleted and recreated on
> a different machine — **without using the words "PersistentVolume," "PVC," or
> "StorageClass."** Describe the claim-check idea in your own words.

**Trade-off / debugging exercise**

> A team's new StatefulSet is stuck: every Pod is `Pending` and the PVCs show
> `Pending` too. They requested `accessModes: ["ReadWriteMany"]` on the cluster's only
> StorageClass, which is backed by cloud block disks. Diagnose it and propose two
> fixes.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A PV is actual storage in the cluster; a PVC is a request that binds to a
  PV. The Pod references the PVC so the binding (and data) outlives any individual
  Pod — on reschedule the new Pod uses the same PVC.
- **Q2:** A StorageClass names a provisioner (CSI driver) and parameters; dynamic
  provisioning means the driver creates a PV on demand when a PVC asks for that class,
  instead of an admin pre-creating PVs.
- **Q3:** Block disks can be attached read-write to only one node at a time (RWO).
  RWX needs a shared network filesystem that multiple nodes can mount simultaneously.
- **Q4:** They are **retained** — deleting a StatefulSet does not delete its PVCs, so
  data survives. You must delete the PVCs yourself to reclaim the storage.
- **Q5:** Edit the PVC's requested `storage` upward; the StorageClass must have
  `allowVolumeExpansion: true` and you generally cannot shrink.
- **Debugging exercise:** RWX can't be satisfied by block-disk storage, so the PVC
  never binds and the Pod can't schedule. Fixes: change the access mode to RWO (if one
  writer per node is acceptable) / RWOP, or add a StorageClass backed by a shared
  filesystem (NFS/Filestore/CephFS) that supports RWX. Confirm with `kubectl describe
  pvc` (events show the provisioning failure) and `kubectl get storageclass`.

</details>

---

## 9. Further reading

- Kubernetes — [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- Kubernetes — [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
- Kubernetes — [Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
- Kubernetes — [Expanding Persistent Volumes Claims](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#expanding-persistent-volumes-claims)
- Kubernetes CSI — [CSI developer and driver documentation](https://kubernetes-csi.github.io/docs/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.4 — Configuration](../04-configuration/)
· _Next:_ [Module 03.6 — RBAC →](../06-rbac/)
