# Module 18.4 — Cost Optimization Patterns

> You can now see cost and attribute it to an owner. This module **reduces** it. The
> waste in a typical cluster is not mysterious — it is a handful of recurring patterns:
> workloads that request far more than they use, dev environments running at 3 a.m.,
> half-empty nodes, on-demand prices for interruptible work, and orphaned disks nobody
> deleted. Each has a specific fix, and the fixes have an **order**. Get the order
> wrong — commit before you right-size — and you lock in the very waste you meant to
> remove.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 03.7 · Resource Management](../../03-kubernetes-fundamentals/07-resource-management/) (VPA, requests), [Module 18.2](../02-kubernetes-cost-management/) and [18.3](../03-cost-attribution/), and a working `kubectl` + [kind](https://kind.sigs.k8s.io/) + [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Classify cluster waste with a **waste taxonomy** and map each type to its fix.
- **Right-size** workloads from VPA recommendations and quantify the saving.
- Apply **spot**, **bin-packing/consolidation**, and **scale-to-zero** safely, knowing
  what each one risks.
- Sequence optimizations in the **correct order** (shrink → pack → buy right → clean).
- Attack **storage, egress, and orphaned resources** — the costs that aren't compute.

---

## 1. Concept

### The waste taxonomy

Every optimization pattern targets a specific kind of waste. Name the waste first:

- **Over-provisioned** — requests far exceed usage. → *right-size.*
- **Idle / always-on** — running when nobody needs it (nights, weekends). → *scale-to-zero.*
- **Poorly packed** — many half-empty nodes. → *bin-pack / consolidate.*
- **Wrong purchase option** — on-demand for interruptible work, or an un-committed steady
  floor. → *spot* and *commitments.*
- **Orphaned** — unattached disks, idle load balancers, reserved IPs, dead namespaces.
  → *delete.*
- **Wrong tier** — hot storage for cold data, avoidable egress. → *tiering / egress
  reduction.*

The rest of this section is one pattern per waste type.

### Pattern 1 — Right-sizing (the biggest, safest lever)

Cost follows **requests** (Module 18.2), and most workloads request far more than they
use "to be safe." Right-sizing pulls requests down toward real usage. The
**Vertical Pod Autoscaler** (Module 03.7) does the observing: in `updateMode: "Off"` it
watches actual consumption and publishes a *recommendation* without touching the pod,
so you can review and apply it deliberately.

The judgment call is *which usage number to target*. Right-size to a **high percentile
plus headroom** (think p95–p99), never the average — a request set to p50 means half the
time the pod is throttled or `OOMKilled`. Right-sizing is high-leverage precisely
because it is low-risk *when you leave headroom*.

### Pattern 2 — Spot for interruptible work

Spot/preemptible capacity is 60–90% cheaper in exchange for being reclaimable with
little notice (Module 18.1). The rule is simple: **spot is for work that can die and
retry** — batch jobs, CI runners, dev environments, and stateless replicas that have
siblings. Make it safe with **PodDisruptionBudgets**, spreading replicas across nodes,
and an **on-demand fallback** when spot capacity disappears. Never put a stateful
singleton or a critical control-plane component on spot.

### Pattern 3 — Bin-packing and consolidation

The scheduler places pods by request, but it does not *re-pack* them as workloads come
and go, so you drift into many half-full nodes. **Karpenter** fixes this with
**consolidation**: it continuously looks for pods it could move onto fewer, fuller nodes
and then removes the emptied ones — and when it does add a node, it provisions a
right-sized one just-in-time. This is the pattern that turns the **node efficiency** gap
from Module 18.2 back into money. Consolidation causes controlled pod churn, so it
**respects PodDisruptionBudgets**. (The older Cluster Autoscaler only adds/removes nodes
for pending pods; it does not actively re-pack.)

### Pattern 4 — Scale-to-zero off-hours

A production service can't scale to zero, but your **dev, staging, and preview**
environments have no reason to run nights and weekends — which is roughly **two-thirds
of the week**. Scaling non-prod workloads to zero on a schedule (a CronJob, or a KEDA
cron scaler) simply deletes that spend. The engineering detail is **restoring the right
replica count** in the morning, so real implementations store the original count (for
example in an annotation) rather than hard-coding it.

### Pattern 5 — Commitments on the lean floor

Once requests are right-sized and nodes consolidated, you have a true **steady floor** —
the capacity that genuinely runs 24/7. *That* is what you commit to with a 1-year CUD or
reservation (Module 18.1), and the platform makes the commitment for the whole fleet.
The ordering is the whole point: committing *before* right-sizing buys a discount on
bloat.

### Pattern 6 — Storage tiering and egress

The non-compute costs are easy to ignore and add up:

- **Storage** — delete unattached volumes and old snapshots, right-size over-provisioned
  disks, and move cold data down the tiers (standard → nearline → coldline → archive).
- **Egress** — keep chatty traffic in-zone/in-region, front static assets with a **CDN**,
  and avoid shipping uncompressed logs out of the cloud.

### Pattern 7 — Delete idle resources

Orphaned load balancers, unattached persistent disks, reserved-but-unused IPs, abandoned
namespaces, and old container images all bill for nothing. Detect them (OpenCost's idle
view, cloud recommenders) and delete them on a grace period — ideally automatically.

### The order matters

```text
1. SHRINK    right-size requests to real usage        → fewer resources per pod
2. PACK      consolidate pods onto fewer, fuller nodes → fewer nodes
3. SLEEP     scale non-prod to zero off-hours          → fewer node-hours
4. BUY RIGHT spot for interruptible, CUD for the floor → cheaper per node-hour
5. CLEAN     delete orphaned disks, LBs, namespaces    → stop paying for nothing
```

Always **shrink before you buy.** Right-sizing and consolidation shrink the floor;
commitments and spot make that lean floor cheaper. Reverse the order and you commit to
waste.

---

## 2. Why it matters for platform engineering

- **This is where FinOps pays for itself** — but only on top of attribution. You spend
  your effort on the biggest and most wasteful workloads *because Module 18.3 told you
  which they are.* Optimizing blind is how you save \$5 on a dev pod while a right-sizing
  opportunity worth thousands sits untouched.
- **The patterns are platform capabilities, not per-team chores.** Consolidation, spot
  node pools, off-hours schedules, and fleet commitments are things the platform
  operates once and every team inherits — the paved road, applied to cost.
- **Optimization must not trade away reliability.** Every pattern here has a failure mode
  (OOM from over-tight requests, outages from spot reclaim, disruption from
  consolidation). Doing them *safely* — headroom, PDBs, non-prod only — is the platform's
  responsibility and the subject of the cost/quality/reliability triangle in Module 18.5.
- **Right-sizing closes the loop with Module 03.7.** The requests you learned to set
  there are the single biggest cost lever; VPA makes setting them data-driven instead of
  guesswork.

---

## 3. Mental model

Climb the **optimization ladder** top to bottom; each rung multiplies the next:

```text
                                                        risk    typical first win
   1. SHRINK   right-size requests (VPA)          ▇▇▇▇  low     20–50% of requests
   2. PACK     consolidate nodes (Karpenter)      ▇▇▇   medium  30–40% fewer nodes
   3. SLEEP    scale non-prod to zero off-hours   ▇▇    low     ~65% off dev spend
   4. BUY RIGHT spot + committed-use discounts    ▇▇▇▇  medium  60–90% (spot) / ~57% (CUD)
   5. CLEAN    delete orphaned disks/LBs/ns       ▇     low     pure waste removed

   Golden rule: SHRINK before you BUY RIGHT — never commit to bloated requests.
```

The mnemonic: **shrink, pack, sleep, buy right, clean.** Start at the top (biggest,
safest) and only commit money once the floor is lean.

---

## 4. Minimal implementation

Right-size one workload straight from its VPA recommendation. First read what VPA
learned by watching real usage:

```bash
kubectl get vpa payments-api \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].target}'
# → {"cpu":"27m","memory":"115Mi"}      (it was requesting 1 CPU / 1Gi)
```

Then apply a right-sized request with a little headroom above the recommendation:

```bash
kubectl patch deploy payments-api --type=merge -p '{
  "spec": {"template": {"spec": {"containers": [
    {"name": "nginx", "resources": {"requests": {"cpu": "50m", "memory": "128Mi"}}}
  ]}}}}'
```

The cost math is immediate (Module 18.2's formula): dropping the CPU request from
`1000m` to `50m` cuts this workload's CPU cost by **20×**. Multiply that by five
over-provisioned workloads and you have the lab's headline saving — with no code change
and, because you kept headroom, no reliability cost.

---

## 5. Hands-on lab

You'll implement **three measured optimizations** on kind, all free: (1) install VPA,
read recommendations, and **right-size five over-provisioned workloads**; (2) deploy a
**scale-to-zero CronJob** that puts a dev namespace to sleep and wakes it; and (3) apply
a **Karpenter spot + consolidation** NodePool (cloud-optional starter) while computing
the node-count reduction right-sizing makes possible. You'll record before/after numbers
for each.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Right-size to a percentile, then watch.** Target p95–p99 with headroom and monitor
  for `OOMKilled`/throttling afterward. Requests drift back up over time, so right-sizing
  is continuous, not one-off.
- **VPA and HPA can fight.** Don't run VPA in `Auto` on the *same resource metric* an HPA
  scales on — they oscillate. Use VPA for requests and HPA for replicas on *different*
  signals, or a multidimensional autoscaler.
- **Spot needs blast-radius control.** PodDisruptionBudgets, anti-affinity to spread
  replicas, and an on-demand fallback pool; never 100% of a service's replicas on spot.
- **Consolidation is disruption.** It evicts and reschedules pods, so gate it with PDBs
  and, for sensitive workloads, maintenance windows or rate limits.
- **Scale-to-zero needs state handling.** Preserve the original replica count (annotation
  or a controller), account for cold starts, and never apply it to stateful or
  production workloads.
- **Measure savings and guard against regression.** Record before/after cost per
  optimization and set an efficiency target (e.g. cluster request-utilization > 60%) so
  wins don't silently erode.
- **Automate orphan cleanup carefully.** Dry-run first, grace periods, and an allowlist —
  deleting a "disused" PVC that held real data is an expensive mistake.

---

## 7. Common mistakes

- **Right-sizing to the average.** Setting requests at p50 saves money until the next
  traffic peak throttles or OOMKills the pod. *Fix:* target p95–p99 and leave headroom.
- **Committing before right-sizing.** A 1-year CUD bought against bloated requests locks
  in the waste for a year. *Fix:* shrink and consolidate first, then commit the lean
  floor.
- **Spot for stateful or singleton-critical workloads.** The discount is irresistible
  until a reclaim event kills your only database replica. *Fix:* spot only for
  interruptible, replicated, retryable work — with a PDB and a fallback.
- **Aggressive consolidation without PodDisruptionBudgets.** Re-packing evicts pods; with
  no PDB you can take a service below quorum. *Fix:* set PDBs before enabling
  consolidation.
- **Optimizing the small stuff.** Hours spent shaving a dev pod while the top-five costly
  workloads go untouched. *Fix:* attribute first (Module 18.3), then optimize the biggest
  and least efficient.
- **Treating it as a one-time cleanup.** Requests re-inflate, new orphans appear. *Fix:*
  continuous right-sizing, scheduled orphan sweeps, and an efficiency alert.

---

## 8. Assessment

**Knowledge checks**

1. Name the five rungs of the optimization ladder in order, and state the one golden rule
   about sequencing.
2. Why right-size to p95–p99 rather than the average? What breaks if you pick the average?
3. Which workloads are safe on spot, and which three safeguards make spot usable?
4. What does Karpenter **consolidation** do that the Cluster Autoscaler does not, and which
   Module 18.2 metric does it improve?
5. Why must you right-size *before* buying a Committed Use Discount?

**Concept exercise**

> Explain to a skeptical engineering manager **why right-sizing must come before
> committing to a discount**, using only the idea of a "floor" — without naming VPA,
> Karpenter, or CUDs.

**Trade-off / debugging exercise**

> After a VPA-driven right-sizing, a service that was fine now `OOMKills` under load and
> its p99 latency doubled, even though average CPU looks healthy. What almost certainly
> went wrong, how do you confirm it, and what is the corrected approach — without simply
> reverting all the savings?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Shrink (right-size) → Pack (consolidate) → Sleep (scale-to-zero) → Buy right
  (spot/CUD) → Clean (delete orphans). Golden rule: **shrink before you buy.**
- **Q2:** Requests must cover peaks, not the mean. Set at the average and the pod is
  throttled (CPU) or `OOMKilled` (memory) whenever load exceeds p50 — which is half the
  time.
- **Q3:** Interruptible, replicated, retryable work (batch, CI, dev, stateless replicas).
  Safeguards: PodDisruptionBudgets, spread/anti-affinity, and an on-demand fallback.
- **Q4:** Consolidation actively *re-packs* existing pods onto fewer, fuller nodes and
  removes the emptied ones (Cluster Autoscaler only reacts to pending pods). It improves
  **node efficiency** (allocated ÷ allocatable).
- **Q5:** A commitment is sized to your steady floor; if the floor is inflated by
  over-requests, you lock in a 1–3 year discount on waste. Shrink first so you commit to
  the real floor.
- **Trade-off:** The **memory** request/limit was cut too close to usage, so a load spike
  exceeded it and the kernel OOMKilled the pod; the latency jump is restarts plus CPU
  throttling. Confirm with `kubectl describe pod` (`OOMKilled`, restarts) and the
  memory-usage-vs-limit graph. Fix by right-sizing to **p95–p99 with headroom**, not the
  average — you keep most of the saving while restoring reliability.

</details>

---

## 9. Further reading

- Kubernetes — [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- Karpenter — [Disruption and consolidation](https://karpenter.sh/docs/concepts/disruption/) and [NodePools](https://karpenter.sh/docs/concepts/nodepools/)
- KEDA — [Cron scaler](https://keda.sh/docs/latest/scalers/cron/) (event-driven scale-to-zero)
- Google Cloud — [Committed Use Discounts](https://cloud.google.com/docs/cuds) and [Recommender / idle resource recommendations](https://cloud.google.com/recommender/docs)
- Google Cloud — [Storage classes and tiering](https://cloud.google.com/storage/docs/storage-classes)
- Kubernetes — [PodDisruptionBudget](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) (making spot and consolidation safe)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 18.3 — Cost Attribution and Chargeback](../03-cost-attribution/) · _Next:_ [Module 18.5 — FinOps Culture and Process →](../05-finops-culture-and-process/)
