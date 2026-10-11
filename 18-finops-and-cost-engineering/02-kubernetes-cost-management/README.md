# Module 18.2 — Kubernetes Cost Management

> Your cloud bill is itemized by **node**; your platform is organized by **workload**.
> Nobody is billed for "the `team-payments` deployment" — they're billed for three
> `n2-standard-8` machines that happen to run it alongside four other teams. This
> module closes that gap: it derives the **cost-per-workload** formula from first
> principles, defines **idle cost** and **node efficiency**, and then stands up
> **OpenCost** to compute it automatically and render it in Grafana.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 03.7 · Resource Management](../../03-kubernetes-fundamentals/07-resource-management/) (requests/limits), [Module 18.1](../01-cloud-cost-fundamentals/), and a working `kubectl` + [kind](https://kind.sigs.k8s.io/) + [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Explain the **attribution gap** — why the cloud sees nodes and Kubernetes sees
  workloads — and why it must be bridged with the data the cluster already has.
- Derive and apply the **cost-per-workload formula** from node price and resource
  **requests**.
- Define, compute, and interpret **idle cost** and **node efficiency**.
- Install **OpenCost** on a cluster and query **allocation** by namespace and workload.
- Surface cost data in **Grafana** and use it to find the most expensive and most
  wasteful workloads.

---

## 1. Concept

### The attribution gap

A Kubernetes node is a shared machine. The cloud charges you a single hourly price for
it — say \$0.38/hour for 8 vCPU and 32 GB — regardless of what runs inside. But a node
rarely belongs to one team: the scheduler packs pods from `team-payments`,
`team-search`, and the platform's own logging agents onto the same box. So the invoice
says *"\$0.38/hour for node-7"* and the cluster says *"node-7 runs 11 pods from 4
namespaces,"* and **nothing in either system joins the two**.

```text
   The cloud's view            The cluster's view
   ───────────────             ──────────────────
   node-7: $0.38/hr    ??      node-7 hosts:
                        │         payments-api  (requests 2 CPU / 4Gi)
                        │         search-indexer(requests 3 CPU / 8Gi)
                        │         fluent-bit     (requests 0.1 CPU / 128Mi)
                        ▼         …
             who owes what share of $0.38/hr?
```

Bridging the gap means **splitting each node's price among the pods on it**, using a
share each pod already declares. That share is the pod's **resource request** — the
amount the scheduler reserved for it (Module 03.7). Requests are the natural currency
of attribution because they are *what you reserved and therefore what you pay for*,
whether or not the pod uses it.

### The cost-per-workload formula

A node's hourly price can be split into a **CPU portion** and a **memory portion** (and
GPU/storage where present). Each workload then pays for its fraction of each:

```text
workload cost =  (node CPU cost  × workload CPU request    / node allocatable CPU)
               + (node RAM cost  × workload memory request / node allocatable RAM)
```

Worked example. Price the node's \$0.38/hour as 60% CPU / 40% memory (a typical split
for a general-purpose instance), i.e. a **CPU price** of
`$0.38 × 0.6 ÷ 8 vCPU = $0.0285 per vCPU-hour` and a **memory price** of
`$0.38 × 0.4 ÷ 32 GB = $0.00475 per GB-hour`. A workload requesting **2 vCPU and 4 GB**
costs:

```text
CPU:    2  × $0.0285   = $0.0570 /hr
Memory: 4  × $0.00475  = $0.0190 /hr
                        ─────────
workload               = $0.0760 /hr  →  × 730  ≈  $55.48 / month
```

That is the whole idea. Notice what drives it: the **request**, not the usage. A team
that requests 2 vCPU "to be safe" and uses 0.3 pays for 2. **Cost is downstream of the
requests you set in Module 03.7** — which is why right-sizing (Module 18.4) is the
single biggest optimization lever.

> **Refinement:** real tools charge `max(request, usage)` per resource — you pay for
> what you reserved, but if a burstable pod exceeds its request you pay for the actual
> usage. Requests are the floor; usage above them is still billed.

### Idle cost: the money nobody requested

Add up what every pod on a node requests and you will almost never reach 100% of the
node. The gap is **idle cost** — capacity you are paying for that no workload reserved:

```text
idle cost (per node) = node cost − Σ (cost allocated to its workloads)
```

Suppose node-7 (\$0.38/hr) hosts workloads requesting **3 vCPU and 6 GB** in total:

```text
allocated CPU:  3 × $0.0285  = $0.0855 /hr
allocated RAM:  6 × $0.00475 = $0.0285 /hr
allocated total              = $0.1140 /hr
node cost                    = $0.3800 /hr
idle cost       = 0.38 − 0.114 = $0.2660 /hr   ← 70% of the node is paid-for emptiness
```

Idle is the uncomfortable truth of Kubernetes cost: the per-pod numbers look cheap, yet
the node bill is three times their sum. **Someone always pays for idle** — either you
distribute it to tenants (so their showback reflects the real cost of running them) or
the platform absorbs it as overhead. Either way you can only manage it once you can
*see* it.

### Node efficiency

The flip side of idle is **node efficiency** — how much of what you bought is actually
reserved (or used):

```text
node efficiency = Σ (workload requests) / node allocatable        [reservation view]
                = Σ (workload usage)    / node allocatable        [utilization view]
```

For node-7 above, reservation efficiency is `0.114 / 0.38 ≈ 30%`. A cluster running at
30% efficiency is paying for three machines to do one machine's work. Driving
efficiency up — by right-sizing requests and bin-packing pods onto fewer, fuller nodes
(Module 18.4) — is how you turn idle back into savings.

### OpenCost and Kubecost

You could compute all of this by hand, but not continuously across a live cluster. Two
tools do it for you:

- **OpenCost** — a CNCF project and the **open specification** for Kubernetes cost
  allocation. It reads pod requests/usage from the Kubernetes API and Prometheus,
  applies a cloud price list (or its built-in defaults), and exposes an **allocation
  API** plus Prometheus metrics. Free and self-hosted.
- **Kubecost** — a commercial product built *on* OpenCost, adding a polished UI,
  long-term retention, savings recommendations, and enterprise features. The allocation
  engine underneath is the same OpenCost model.

We use **OpenCost** because it is free, runs on kind, and teaches the model honestly —
you can see exactly how the numbers are derived rather than trusting a black box.

### Where the data lands: Grafana

OpenCost exports its allocation as **Prometheus metrics**, which means cost becomes just
another time series next to the latency and saturation dashboards you built in
[Phase 11](../../11-observability-engineering/) and
[Project 3](../../12-platform-project-03/). Cost-per-namespace graphs live in the same
Grafana, refreshed on the same cadence — cost treated as a first-class signal, not a
monthly spreadsheet.

---

## 2. Why it matters for platform engineering

- **Attribution is the platform's job because only the platform has both halves.** Teams
  see their workloads; finance sees the invoice. Only the platform operates the cluster
  *and* knows the node prices, so only it can join them. This is a structural
  responsibility, like owning the security baseline.
- **It makes over-provisioning visible and therefore fixable.** Without per-workload
  cost, "just request 4 CPUs to be safe" is invisible. With it, that padding shows up as
  a line a team can see and own — the precondition for every optimization in Module 18.4.
- **Idle is a platform metric, not a team one.** Low node efficiency usually means the
  *platform's* bin-packing, node sizing, or autoscaling needs work — a problem no single
  team can fix.
- **It closes the loop with observability.** You already ship metrics to Prometheus and
  dashboards to Grafana. Cost rides the same rails, so "what does reliability cost?"
  becomes answerable on one screen.

---

## 3. Mental model

Think of a node as a **rented apartment** and pods as **tenants**:

```text
                 node-7  ($0.38/hr rent, 8 CPU / 32Gi of floor space)
   ┌───────────────────────────────────────────────────────────────┐
   │  payments-api   ██████            (requests 2 CPU / 4Gi)        │  pays its share
   │  search-indexer ████████████      (requests 3 CPU / 8Gi)       │  pays its share
   │  fluent-bit     ▌                 (requests 0.1 CPU / 128Mi)   │  pays its share
   │                                                                │
   │  . . . . . . . EMPTY ROOMS YOU STILL PAY RENT ON . . . . . . . │  idle cost
   └───────────────────────────────────────────────────────────────┘
      efficiency = reserved floor space ÷ total floor space ≈ 30%
```

- **Rent** = node price (fixed, whether rooms are full or empty).
- **Each tenant's bill** = their reserved floor space (their *request*) as a share of
  the apartment.
- **Idle** = the empty rooms — paid for, used by no one.
- **Efficiency** = how full the apartment is. The platform's goal is a full apartment,
  not a bigger one.

The rule: **you pay for what you reserve, not what you use.** Attribution follows
requests; waste is the gap between requests and reality.

---

## 4. Minimal implementation

Before installing anything, compute a pod's cost by hand from data the cluster already
has. Read a workload's requests with `kubectl`, then apply the formula:

```bash
# What does this deployment request?
kubectl get deploy payments-api -o \
  jsonpath='{.spec.template.spec.containers[*].resources.requests}'
# → {"cpu":"2","memory":"4Gi"}
```

```bash
# Turn requests + node price into a monthly cost (the OpenCost model, by hand)
NODE_HOURLY=0.38 ; NODE_CPU=8 ; NODE_MEM_GB=32
POD_CPU=2        ; POD_MEM_GB=4
cpu_price=$(echo "$NODE_HOURLY * 0.6 / $NODE_CPU"    | bc -l)   # 60% of node price is CPU
mem_price=$(echo "$NODE_HOURLY * 0.4 / $NODE_MEM_GB" | bc -l)   # 40% is memory
pod_hr=$(echo "$POD_CPU*$cpu_price + $POD_MEM_GB*$mem_price" | bc -l)
printf 'payments-api: $%.4f/hr  ≈  $%.2f/month\n' "$pod_hr" "$(echo "$pod_hr*730" | bc -l)"
# → payments-api: $0.0760/hr  ≈  $55.48/month
```

That script *is* OpenCost in miniature: read requests, split the node price, multiply by
time. OpenCost just does it for every pod, every node, continuously, with real prices —
which is what the lab installs next.

---

## 5. Hands-on lab

You'll install **OpenCost** via Helm on a local kind cluster, deploy a few workloads with
deliberately varied requests, then query the **allocation API** to rank spend by
namespace, find the **top-5 most expensive** workloads, and spot an **idle** namespace.
Finally you'll point Grafana at OpenCost's metrics. It runs **free** — OpenCost uses its
default price list to produce *estimated* costs on kind.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Accuracy depends on the price list.** On kind, OpenCost estimates with built-in
  defaults. In production you wire it to your cloud's real pricing (and your negotiated
  rates / CUDs) so the numbers match the invoice — otherwise showback loses credibility.
- **`max(request, usage)` and shared costs.** Decide how you allocate idle and shared
  platform overhead (logging, ingress): spread it proportionally across tenants, or hold
  it in a `platform` namespace. Both are defensible; pick one and document it.
- **Network costs are harder.** CPU and memory are easy; attributing egress between pods
  needs OpenCost's network daemonset and is inherently approximate. Treat network cost as
  directional, not exact.
- **Prometheus retention is your cost history.** Allocation is only as long-lived as the
  metrics behind it. Size retention (or a long-term store like Thanos/Mimir) for the
  reporting window you need — a month of cost history needs a month of metrics.
- **Run OpenCost as a platform service.** It's one more component you operate: resource
  it, monitor it, and alert if it stops scraping, because silent cost blindness is worse
  than no dashboard.

---

## 7. Common mistakes

- **Allocating by usage instead of request.** Billing a pod only for the CPU it burned
  hides the capacity it *reserved* and made unavailable to others. *Fix:* allocate on
  `max(request, usage)` — you pay for what you hold.
- **Ignoring idle cost.** Per-pod numbers look cheap, so the cluster seems efficient
  while half the node bill is emptiness. *Fix:* track node efficiency and idle as
  first-class metrics; idle is the optimization target, not a rounding error.
- **Believing kind's dollar figures.** OpenCost on kind is *estimated*; treating those
  numbers as your real bill will embarrass you in a FinOps review. *Fix:* integrate real
  cloud pricing before anyone makes decisions on the figures.
- **Workloads with no requests.** BestEffort pods (no requests) show near-zero cost yet
  consume real CPU and memory, corrupting every allocation. *Fix:* enforce requests via
  LimitRange/quotas (Module 03.7) so every pod is attributable.
- **Treating cost as a monthly export.** A spreadsheet that arrives after the money is
  spent changes nothing. *Fix:* put cost in Grafana next to your SLO dashboards so it's
  seen continuously.

---

## 8. Assessment

**Knowledge checks**

1. State the cost-per-workload formula and explain why it uses **requests** rather than
   actual usage.
2. A node costs \$0.40/hr (8 CPU / 32 GB, split 50/50 CPU/RAM). A pod requests 1 CPU and
   8 GB. What does the pod cost per month (~730 hr)?
3. Define **idle cost** and **node efficiency**, and explain how they relate.
4. Why are OpenCost's figures "estimated" on a kind cluster, and what makes them accurate
   in production?
5. Why does a BestEffort pod (no requests) break cost allocation?

**Concept exercise**

> Explain how you would fairly split one shared node's monthly bill among the five teams
> whose pods run on it — **without naming OpenCost or Kubecost.** What number do you
> divide by, and how do you handle the part of the node nobody reserved?

**Trade-off / debugging exercise**

> A cluster's OpenCost dashboard shows every namespace is "cheap," yet the cloud bill for
> the node pool is twice the sum of all namespace costs. Nothing is mislabeled. What is
> the most likely explanation, which metric confirms it, and what are two ways to fix it?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** `cost = (nodeCPUcost × CPUrequest/allocatableCPU) + (nodeRAMcost ×
  RAMrequest/allocatableRAM)`. It uses requests because requests are what the scheduler
  *reserved* and therefore what you pay for, used or not.
- **Q2:** CPU price = `0.40 × 0.5 / 8 = $0.025/vCPU-hr`; RAM price = `0.40 × 0.5 / 32 =
  $0.00625/GB-hr`. Pod = `1×0.025 + 8×0.00625 = 0.025 + 0.05 = $0.075/hr` → `× 730 ≈
  **$54.75/month**`.
- **Q3:** Idle cost = node cost − cost allocated to its workloads (paid-for capacity no
  one requested). Node efficiency = Σ requests ÷ allocatable. High idle ⇔ low efficiency;
  they are two views of the same gap.
- **Q4:** On kind there's no cloud invoice, so OpenCost uses a default price list — the
  *model* is right but the *rates* are generic. Wiring real cloud pricing (and your CUD/
  spot rates) makes them match the bill.
- **Q5:** With no requests, its allocation share is ~0, so it appears free while really
  consuming CPU/RAM — distorting every other workload's computed share.
- **Trade-off:** The gap is **idle cost** — the node pool is poorly packed, so most of
  each node is paid-for emptiness not attributed to any namespace. Confirm with **node
  efficiency** (requests ÷ allocatable). Fix by **right-sizing requests** (Module 18.4
  VPA) and **bin-packing onto fewer nodes** (consolidation / Karpenter).

</details>

---

## 9. Further reading

- OpenCost — [Documentation](https://www.opencost.io/docs/) and the [cost allocation specification](https://www.opencost.io/docs/specification)
- OpenCost — [Installing with Helm](https://www.opencost.io/docs/installation/install) and the [Allocation API](https://www.opencost.io/docs/integrations/api)
- Kubecost — [How cost allocation works](https://docs.kubecost.com/using-kubecost/navigating-the-kubecost-ui/cost-allocation)
- CNCF — [OpenCost project](https://www.cncf.io/projects/opencost/)
- Kubernetes — [Resource requests and limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/) (the inputs to the formula)
- Grafana — [OpenCost dashboards](https://grafana.com/grafana/dashboards/) (search "OpenCost")

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 18.1 — Cloud Cost Fundamentals](../01-cloud-cost-fundamentals/) · _Next:_ [Module 18.3 — Cost Attribution and Chargeback →](../03-cost-attribution/)
