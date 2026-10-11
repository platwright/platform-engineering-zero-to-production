# Module 17.4 — Platform Capacity Planning

> A platform must have **enough** compute for every team's workloads — but not so much
> that you burn money on idle nodes. Too tight and pods go `Pending` and incidents
> follow; too loose and the cloud bill balloons. This module covers node-pool design,
> the autoscaling stack (HPA/VPA for pods, Cluster Autoscaler and Karpenter for
> nodes), forecasting from adoption, and right-sizing from real usage.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Phase 3 · Kubernetes](../../03-kubernetes-fundamentals/) (requests,
limits, scheduling), a local [kind](https://kind.sigs.k8s.io/) cluster, `kubectl`, and
metrics-server. The live Karpenter steps are **cloud-optional** (see the lab note).

## Learning objectives

By the end of this module you will be able to:

- Plan cluster capacity: how many nodes, which sizes, and in which **node pools**.
- Place the four autoscalers — **HPA, VPA, Cluster Autoscaler, Karpenter** — and say
  what each one scales.
- Explain how **Karpenter** right-sizes nodes to pod requests, prefers **spot**, and
  **consolidates** underutilized nodes.
- **Forecast** capacity from team-adoption trends.
- **Right-size** workloads by comparing actual usage to requests over time.

---

## 1. Concept

### The capacity problem has two failure modes

Capacity planning is a balance between two expensive mistakes:

```text
   too TIGHT  ◄───────────────────────────────►  too LOOSE
   pods Pending, evictions,                        nodes idle at 20% utilization,
   throttling, incidents                           paying for air
   (reliability cost)                              (money cost)
```

The whole discipline is finding the middle: enough headroom to absorb spikes and node
failures, without paying for capacity nobody uses. On a platform this is multiplied —
you are provisioning for *every* team, so a 20% waste is 20% of a very large bill, and
a shortage blocks many teams at once.

### Requests are the currency of capacity

Kubernetes schedules on **requests**, not actual usage (Phase 3). A pod's CPU/memory
*requests* reserve space on a node; the scheduler bin-packs pods onto nodes until
requests fill allocatable capacity. Two consequences drive everything in this module:

- **Over-requesting wastes capacity.** A pod that requests 1 CPU but uses 0.1 holds a
  whole CPU of reservation idle. Multiply across a platform and you buy nodes for
  requests nobody uses — the number-one source of cluster waste.
- **Under-requesting causes incidents.** A pod that requests too little gets scheduled
  onto a crowded node and then starves or is OOM-killed under load.

So "capacity planning" is really two jobs: **provision the right nodes** for the
requests, and **make the requests match reality** (right-sizing).

### Node-pool design

You rarely want one uniform node type. Different workloads need different shapes, so
you define **node pools** (node groups), each a template for a class of node:

```text
pool               shape                         workloads
─────────────────  ────────────────────────────  ───────────────────────────────
general-purpose    balanced CPU:memory (m-class)  most services, controllers
compute-optimized  high CPU (c-class)             build agents, CPU-bound jobs
memory-optimized   high memory (r-class)          caches, in-memory data
GPU                accelerators                    ML training/inference
spot               interruptible, cheap           fault-tolerant batch, stateless
```

Pools let you match workloads to hardware, isolate noisy neighbors, and target
cheap **spot** capacity at workloads that tolerate interruption. Taints/labels steer
pods to the right pool (Phase 3 scheduling).

### The autoscaling stack: four autoscalers, four jobs

Autoscaling has two axes — pods and nodes — and a tool for each:

```text
          scales PODS                         scales NODES
        ┌───────────────────────┐           ┌──────────────────────────────┐
  OUT   │ HPA: more/fewer        │           │ Cluster Autoscaler: add/remove│
 (count)│ replicas on a metric   │           │ nodes within fixed node pools │
        └───────────────────────┘           └──────────────────────────────┘
  UP    ┌───────────────────────┐           ┌──────────────────────────────┐
 (size) │ VPA: adjust a pod's    │           │ Karpenter: provision right-   │
        │ requests to fit usage  │           │ sized nodes on demand, any    │
        └───────────────────────┘           │ shape, prefer spot, consolidate│
                                             └──────────────────────────────┘
```

- **HPA (Horizontal Pod Autoscaler)** — adds/removes *replicas* based on CPU, memory,
  or custom metrics. Handles load that scales horizontally.
- **VPA (Vertical Pod Autoscaler)** — recommends/sets a pod's *requests* to match
  observed usage. The automation behind right-sizing (use in recommend mode first).
- **Cluster Autoscaler (CA)** — adds/removes *nodes* from **predefined node groups**
  when pods are `Pending` or nodes are empty. Node sizes are fixed by the groups.
- **Karpenter** — a newer node autoscaler that provisions **just-in-time, right-sized**
  nodes of whatever shape best fits the pending pods, chooses **spot** when allowed,
  and **consolidates** underutilized nodes by replacing or removing them.

HPA and CA are the classic pairing; VPA + Karpenter is the modern, efficiency-focused
pairing. They compose: HPA adds replicas → requests exceed capacity → Karpenter/CA add
nodes.

### Karpenter: nodes shaped to the work

Cluster Autoscaler scales *within* node groups you defined up front, so it can only add
more of a shape you already chose. **Karpenter** flips this: you describe *constraints*
(allowed instance families, architectures, capacity types) in a `NodePool`, and
Karpenter looks at the **actual pending pods** and launches the cheapest node that
fits them — right-sizing the node to the work instead of the work to the node.

Three Karpenter behaviors matter for a platform:

- **Right-sizing.** It bin-packs pending pods and picks an instance type that fits,
  avoiding both tiny-node sprawl and giant half-empty nodes.
- **Spot preference with fallback.** Allow both `spot` and `on-demand` capacity types
  and Karpenter prefers cheap spot, falling back to on-demand when spot is
  unavailable — large savings for interruption-tolerant work.
- **Consolidation.** On low utilization it actively **consolidates**: it removes empty
  nodes and replaces underused ones with cheaper/smaller nodes, continuously driving
  the cluster toward the minimum cost that still fits the requests.

### Forecasting from adoption

A platform's capacity demand tracks **adoption**, not calendar time. The signal is the
onboarding pipeline: teams coming on, services per team, and their request footprint.

```text
forecast ≈ (current requested CPU/mem)
         × (projected teams / current teams)
         × (growth per team)
         + headroom for spikes and node-failure tolerance
```

You do not need a data-science model — a simple trend from "requested resources per
month" plus the onboarding roadmap gets you a defensible number for the next quarter.
The point is to provision *ahead* of adoption so new teams are not blocked, while
autoscaling absorbs the day-to-day variation.

### Right-sizing: usage versus requests

The highest-leverage efficiency work is closing the gap between **requests** and
**actual usage**. The method:

- Observe actual CPU/memory over a representative window (e.g. 30 days, including peaks)
  from Prometheus or `kubectl top`.
- Compare to requests. A pod requesting 1 CPU and using a p95 of 0.15 is massively
  over-provisioned; one using a p95 of 0.95 against a 1 CPU request is at risk.
- Recommend new requests at roughly **p95 usage + headroom** — enough for peaks, not
  for imaginary load. VPA automates exactly this recommendation.

Right-sizing is continuous (usage drifts) and it is a platform service: you give teams
a report or a VPA recommendation so their defaults improve, which shrinks the cluster
Karpenter has to provision.

---

## 2. Why it matters for platform engineering

- **Capacity is a reliability *and* a cost control.** The same lever that prevents
  `Pending`-pod incidents also governs the biggest line on the platform bill. Get it
  wrong tight and teams are blocked; wrong loose and finance comes asking (Phase 14).
- **You provision for everyone.** A platform's waste and shortage are both multiplied
  across all teams, so efficiency work here has outsized leverage.
- **Right-sizing is scalable toil elimination.** Instead of arguing requests with each
  team, the platform ships good defaults and a recommendation pipeline — the paved
  road stays efficient by default.
- **Autoscaling turns capacity into a property, not a project.** Well-configured
  Karpenter/HPA means capacity tracks demand automatically, freeing the team from
  manual node math (Module 17.1 toil).

---

## 3. Mental model

Think of the cluster as a **moving van** you rent by the cubic metre. **Requests** are
the box sizes teams declare; the scheduler **packs boxes into vans**; Karpenter
**rents exactly enough vans of the right size, prefers the cheap off-peak rate (spot),
and returns half-empty vans (consolidation)**. Right-sizing is making teams label their
boxes honestly so you do not rent vans for air.

```text
   teams declare box sizes (requests)
        │  (often bigger than what's inside → right-sizing fixes this)
        ▼
   scheduler packs boxes into vans (bin-pack onto nodes)
        │  boxes don't fit? → pods Pending
        ▼
   Karpenter rents vans to fit the boxes:
        ├─ right-sized (smallest van that fits the pending boxes)
        ├─ spot rate preferred, on-demand fallback
        └─ consolidation: return empty/half-empty vans, repack cheaper
        │
        ▼
   result: enough capacity for everyone, minimal money spent on air
```

The durable idea: **you pay for requests, not usage — so capacity planning is node
provisioning (Karpenter) plus honest requests (right-sizing), with headroom for
failure.**

---

## 4. Minimal implementation

First, *see* the capacity problem from first principles: schedule more requests than a
node can hold and watch a pod go `Pending` with nowhere to run — the exact condition a
node autoscaler reacts to.

```bash
# how much is allocatable vs already requested?
kubectl describe node | grep -A5 "Allocated resources"

# ask for more CPU than any node can give → Pending
kubectl create deployment hog --image=registry.k8s.io/pause:3.9 --replicas=5
kubectl set resources deployment/hog --requests=cpu=2
kubectl get pods -l app=hog    # some stay Pending: "0/ N nodes available: insufficient cpu"
```

On a managed cluster, a Karpenter `NodePool` turns that `Pending` into a right-sized,
spot-preferring node automatically — and consolidation removes it when the load drops:

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]   # prefer spot, fall back to on-demand
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized   # consolidate idle nodes
    consolidateAfter: 1m
```

The lab validates the full `NodePool` and lets you watch pending pods, bin-packing, and
a right-sizing calculation locally — Karpenter's live provisioning is the cloud-optional
extension.

```bash
# right-sizing signal: actual usage vs requests
kubectl top pods --containers
```

## 5. Hands-on lab

You will provoke and read the capacity signal on a local cluster (requests, bin-packing,
`Pending` pods), validate a Karpenter `NodePool` with spot preference and consolidation,
and produce a **right-sizing recommendation** from real usage. Karpenter's live node
provisioning is a clearly-marked, cost-noted cloud extension.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Keep failure headroom.** Provision so that losing a node (or an AZ) does not cause
  `Pending` pods for critical workloads. Autoscaling reacts in minutes; headroom covers
  the gap. Use PodDisruptionBudgets so consolidation and upgrades respect availability.
- **Spot needs interruption-tolerance.** Spot is cheap because it can be reclaimed.
  Put stateless, retry-safe, or batch work on spot; keep stateful and critical
  singletons on on-demand. Spread across instance types to reduce correlated reclaims.
- **VPA and HPA conflict on the same metric.** Do not run HPA and VPA both on CPU for
  the same workload — they fight. Use HPA on a load metric and VPA (or manual
  right-sizing) on requests, or VPA in *recommend-only* mode.
- **Consolidation causes churn.** Aggressive consolidation saves money but reschedules
  pods; tune `consolidateAfter` and protect latency-sensitive apps with PDBs so you do
  not trade cost for instability.
- **Right-size continuously, from peaks.** Usage drifts and traffic is spiky; size on
  p95-including-peaks, not averages, and revisit regularly. Ship recommendations to
  teams rather than silently changing their requests.
- **Forecast ahead of onboarding.** Tie capacity reviews to the adoption roadmap so new
  teams never wait on nodes; let autoscaling handle the noise, not the trend.

## 7. Common mistakes

- **Sizing on usage, scheduling on requests.** — Teams watch CPU graphs but set
  requests arbitrarily, so the cluster is full of reservation nobody uses. *Fix:*
  right-size requests to p95 usage + headroom; that is what the scheduler actually
  packs.
- **One giant node pool.** — Every workload on identical nodes wastes money and mixes
  noisy neighbors. *Fix:* purpose-built pools (general, compute, memory, GPU, spot)
  with taints/labels.
- **Putting stateful workloads on spot.** — A reclaimed spot node kills a database
  pod. *Fix:* spot for interruption-tolerant work only; on-demand for critical state.
- **HPA and VPA on the same signal.** — They oscillate against each other. *Fix:*
  separate the metrics, or run VPA in recommend mode.
- **No failure headroom.** — The cluster is packed to 100% of requests, so one node
  loss causes `Pending` pods and an incident. *Fix:* plan explicit headroom and PDBs.
- **Treating capacity as a one-time project.** — Provision once, never revisit, and
  drift into waste or shortage. *Fix:* continuous right-sizing and adoption-driven
  forecasting.

## 8. Assessment

**Knowledge checks**

1. What are the two failure modes of capacity planning, and what does each cost?
2. Does Kubernetes schedule on requests or on actual usage, and why does that make
   right-sizing the key efficiency lever?
3. Match each autoscaler (HPA, VPA, Cluster Autoscaler, Karpenter) to what it scales.
4. How does Karpenter differ from Cluster Autoscaler in how it chooses node size?
5. What does "consolidation" do, and what risk does it introduce?

**Concept exercise**

> Explain to a team why their service "only using 10% CPU" is still costing the
> platform a lot of money — **without using the word "requests."**

**Trade-off / debugging exercise**

> A platform runs one general-purpose on-demand node pool at 35% average CPU
> utilization, and teams occasionally see `Pending` pods during deploys. The cloud
> bill is the biggest complaint. Propose a capacity redesign (pools, autoscaling,
> spot, right-sizing) and explain how each change helps cost *or* reliability — and
> which changes risk trading one for the other.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Too tight → `Pending` pods, evictions, throttling (reliability cost); too
  loose → idle nodes you pay for (money cost). Capacity planning finds the middle with
  headroom.
- **Q2:** On **requests**. Reservations, not usage, consume schedulable capacity, so a
  gap between requests and usage is capacity you buy and never use — closing it (right-
  sizing) is the biggest efficiency win.
- **Q3:** HPA → replica count; VPA → a pod's requests (size); Cluster Autoscaler →
  node count within fixed node groups; Karpenter → just-in-time right-sized nodes of
  any allowed shape.
- **Q4:** CA adds more of a *predefined* node-group shape; Karpenter inspects the
  pending pods and launches the cheapest instance type that fits them, so the node is
  shaped to the work.
- **Q5:** Consolidation removes empty nodes and replaces underutilized ones with
  cheaper nodes to cut cost; the risk is churn — it reschedules pods, which can hurt
  latency-sensitive workloads unless protected by PDBs and tuned timing.
- **Trade-off:** 35% utilization signals over-provisioning *and* the `Pending` pods
  signal missing burst headroom/autoscaling — both at once because requests are likely
  inflated and nodes are fixed. Redesign: right-size requests (reclaims the idle 65%),
  add Karpenter for just-in-time nodes (kills the `Pending` during deploys *and*
  consolidates idle capacity), move stateless/batch to a spot pool (big cost cut),
  keep critical state on on-demand with headroom + PDBs. Risk trades: aggressive
  consolidation and spot cut cost but add churn/reclaim risk — bound them with PDBs
  and workload placement.

</details>

## 9. Further reading

- Karpenter — [Documentation](https://karpenter.sh/docs/) and
  [Concepts: NodePools & Disruption](https://karpenter.sh/docs/concepts/disruption/)
- Kubernetes — [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- Kubernetes Autoscaler — [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
  and [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- Google — [SRE Workbook: Managing Load](https://sre.google/workbook/managing-load/)
- AWS — [Karpenter best practices (EKS)](https://aws.github.io/aws-eks-best-practices/karpenter/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [17.3 — Platform Incident Management](../03-platform-incident-management/)
· _Next:_ [17.5 — Chaos Engineering for Platforms →](../05-chaos-engineering-for-platforms/)
