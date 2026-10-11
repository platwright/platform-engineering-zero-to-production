# Module 18.1 — Cloud Cost Fundamentals

> The cloud looks infinite and the pricing page hides a simple truth: you are
> renting physical machines, disks, and network links by the second. Three ways to
> buy compute, four cost components, and one discipline — tag everything — explain
> most of any cloud bill. This module teaches you to **read and model a bill from
> first principles**, before any Kubernetes cost tooling, so the numbers in the rest
> of the phase mean something.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 03.7 · Resource Management](../../03-kubernetes-fundamentals/07-resource-management/) (recommended) and a calculator. **No cloud account required** — the lab is a worksheet.

## Learning objectives

By the end of this module you will be able to:

- Distinguish the **three purchase options** — on-demand, committed, spot — and match
  each to a workload's risk profile.
- Break a bill into its **four cost components** (compute, storage, network, managed
  services) and say which are usage-based and which are provisioned.
- Explain why **egress** is the most commonly missed cost and where it hides.
- **Model** a workload's monthly cost by hand and quantify the savings from
  commitment and spot.
- Describe the **billing hierarchy** (accounts, budgets, alerts) and why **allocation
  tags** are mandatory, not optional.

---

## 1. Concept

### One formula underneath everything

Strip away the pricing-page complexity and every charge is the same shape:

```text
cost = Σ (unit rate × quantity × time)  −  discounts
```

A vCPU-second, a gigabyte-month, a gigabyte transferred, an API call — each has a
*rate*, you consume some *quantity* for some *time*, and commitments or spot apply a
*discount*. Everything below is detail about what the unit is and how the rate is
set. Hold this formula; it is the only mental arithmetic FinOps really requires.

### The three ways to buy compute

The single biggest lever on a compute bill is not *what* you run but *how you buy
it*. The same node can cost wildly different amounts:

- **On-demand.** Pay per second, no commitment, cancel anytime — at the highest rate.
  You are paying a premium for flexibility. The right default for anything new,
  spiky, or short-lived.
- **Committed** (reservations, Committed Use Discounts, savings plans). You promise to
  keep spending — or keep a resource — for **1 or 3 years**, and in exchange the rate
  drops steeply. On GCP, a 3-year resource-based **CUD** reaches roughly **57% off**.
  You pay for the commitment **whether or not you use it**, so it only saves money on
  capacity that genuinely runs all the time.
- **Spot / preemptible.** The cloud sells its spare capacity at **60–90% off**, on one
  condition: it can take it back with little warning (often ~30 seconds; GCP's older
  preemptible VMs also cap at a 24-hour life). Perfect for work that can be
  interrupted and retried; unacceptable for anything that must not vanish.

```text
A hotel analogy:
  on-demand  = walk-up rack rate .......... most expensive, leave whenever
  committed  = prepaid non-refundable block . cheap, but you pay even if you no-show
  spot       = standby room at 80% off ...... cheapest, but they can bump you tonight
```

### The four cost components

Compute dominates most bills, but it is never the whole story. Learn to look for all
four:

- **Compute** — VMs / nodes billed per second while running (vCPU + memory). Usually
  the majority of the bill and the focus of most optimization.
- **Storage** — persistent (block) disks, object storage, and snapshots, billed per
  **GB-month**. Crucially, block storage is **provisioned**: you pay for the size you
  allocated, not the bytes you wrote. Tiers (standard SSD → cold → archive) trade
  retrieval speed for price.
- **Networking** — the subtle one. **Ingress is usually free; egress is charged.**
  Data leaving to the internet, crossing zones or regions, NAT gateways, and load
  balancers all accrue. More on this below.
- **Managed services** — databases, queues, registries, logging/monitoring, and the
  managed Kubernetes control plane each priced in their own units. Convenient, and
  easy to forget in a cost model.

### Egress: the cost that hides

Egress deserves its own section because it is the line item that surprises people:

- Replicating data **across availability zones** for high availability.
- Chatty microservices whose pods land in **different zones** and talk constantly.
- Pulling container images or datasets **from another region**.
- Shipping logs and metrics **out** to a third-party SaaS.
- Serving user traffic and large assets **to the internet**.

None of it shows up while you build; all of it shows up on the invoice. The fixes are
architectural — schedule chatty workloads together, keep traffic in-region, put a CDN
in front of static assets, use private interconnects — which is exactly why egress is
a **platform** concern, not something an app team can fix alone.

### Buying strategy, with numbers

You rarely pick one option for everything. You **blend**:

- Put the **always-on floor** (databases, the steady base of a web tier, the control
  plane) on **committed** capacity — it runs 24/7, so the discount is pure savings.
- Put **steady-but-variable** load on **on-demand** so you can scale without
  over-committing.
- Put **interruptible** work — batch jobs, CI, dev environments, ML training — on
  **spot**, with an on-demand fallback for when capacity is reclaimed.

The risk on committed is **over-commitment** (paying for a floor that shrank); the
risk on spot is **interruption**. Both are manageable with measurement, which is what
the rest of this phase builds.

### The billing hierarchy and its guardrails

Cloud bills are organized as a tree, and attribution starts with its shape:

```text
Organization
└── Billing account
    ├── Project / account: team-payments   ← group spend here
    ├── Project / account: team-search
    └── Project / account: platform-shared
        └── resources (VMs, disks, LBs, …)  ← each should carry allocation tags
```

Two platform guardrails hang off this tree:

- **Budgets and alerts.** You set a budget and get notified at, say, 50% / 90% / 100%.
  The critical caveat: **a budget alert does not stop spending** — it is a smoke
  detector, not a circuit breaker. Capping spend requires automation or a human.
- **Allocation tags / labels.** Every resource should carry `team`, `environment`, and
  `application` (or `cost-center`) labels so the one big number can be split by owner.

### Allocation tags are the linchpin of the whole phase

Without tags, a cloud bill is a single undifferentiated total — you know you spent
$80,000 but not who or what caused it. With consistent `team` / `environment` /
`application` labels, that total becomes a per-team, per-service breakdown you can act
on. This is the seed of everything that follows, and the reason
[Project 1](../../04-platform-project-01/) required these labels on every workload
from day one. **An untagged resource is unattributable spend** — invisible to the very
people who could reduce it.

---

## 2. Why it matters for platform engineering

- **The platform's defaults set everyone's baseline bill.** The instance types you
  offer, the disk tier you default to, whether workloads span zones — these platform
  decisions are multiplied across every team. A one-line default change can move the
  org's bill by a large fraction.
- **Purchase strategy is a fleet-level decision only the platform can make.** An
  individual team cannot buy a Committed Use Discount sensibly; it sees only its own
  slice. The platform commits for the **aggregate floor** of the whole cluster and
  passes the savings down.
- **Tagging is a platform-owned contract.** A consistent label taxonomy is worthless
  if 30% of resources ignore it. You will *enforce* it with Kyverno in Module 18.3 —
  the same move you made for the security baseline in Module 13.3.
- **Modeling cost is an architecture skill.** "Single-region or multi-region?" and
  "how many replicas across how many zones?" are reliability questions *and* cost
  questions. Being able to put a dollar figure on each option makes you a better
  architect, not just a cheaper one.

---

## 3. Mental model

Keep two pictures in your head: the **formula** and the **purchase spectrum**.

```text
cost = Σ (rate × quantity × time) − discounts

Purchase options — price vs risk (same node, three ways to buy it):

  on-demand   ████████████████████  100%   flexible, no lock-in,  interruptible: never
  committed   ████████▌             ~43%   cheapest when ALWAYS on, locked 1–3 years
  spot        ██▌                   10–40% cheapest of all, can be reclaimed in ~30s

Match the option to the workload:

  stateful DB / control plane   → committed (24/7) + a little on-demand headroom
  steady web service            → committed baseline + on-demand for spikes
  batch / CI / dev / ML training → spot (interruptible, retried) + on-demand fallback
```

The rule to remember: **buy your floor committed, your fluctuation on-demand, and your
interruptible work on spot.** Most waste is a workload bought on the wrong option.

---

## 4. Minimal implementation

Before any tooling, model a cluster by hand. Take **3 nodes** of 8 vCPU / 32 GB at an
on-demand rate of **$0.38/hour**, running a full month (~730 hours), plus the storage
and egress nobody remembers:

```text
Compute (on-demand):   3 × $0.38 × 730            = $832.20 / month
  same compute, 3-yr CUD (−57%):  832.20 × 0.43   = $357.85 / month   (save ~$474)
  same compute, spot    (−70%):   832.20 × 0.30   = $249.66 / month   (if interruptible)
Storage:  500 GB SSD × $0.17/GB-month              = $85.00  / month   (paid even if empty)
Egress:   2 TB to internet × $0.12/GB              = $245.76 / month   (the forgotten line)
                                                     ───────────────
On-demand total (compute + storage + egress)       = $1,162.96 / month
```

Two lessons fall straight out of the arithmetic:

- The "server cost" is only ~72% of this bill; **storage and egress quietly add ~40%**
  on top of compute. A model that stops at the VM price is wrong before it starts.
- The **same compute** is \$832 or \$250 a month depending *only* on how you bought it.
  Purchase strategy, not workload size, is often the biggest lever.

You can automate the compute comparison in three lines — the smallest possible cost
model:

```bash
# Monthly on-demand vs 3-year committed vs spot for N identical nodes
NODES=3; RATE=0.38; HOURS=730
on_demand=$(echo "$NODES * $RATE * $HOURS" | bc -l)
committed=$(echo "$on_demand * 0.43" | bc -l)   # ~57% CUD discount
spot=$(echo "$on_demand * 0.30"      | bc -l)   # ~70% spot discount
printf 'on-demand $%.2f | committed $%.2f | spot $%.2f\n' "$on_demand" "$committed" "$spot"
```

That is the entire idea of this module in one script: pick the unit, pick the rate,
multiply by time, apply the discount. The lab turns it into a reusable worksheet.

---

## 5. Hands-on lab

You'll build a **cost-model worksheet** for a reference platform: three node groups,
storage, and egress, priced three ways (on-demand, committed, spot). You'll compute
the effective monthly bill, find the cheapest safe blend, and — optionally — check
your numbers against a real cloud pricing calculator.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Budgets alert; they do not cap.** To actually stop runaway spend you need
  automation (a function that disables a project) or an on-call human. Treat the alert
  as the *start* of a response, never the control itself.
- **Commitment coverage and utilization are metrics to watch.** A CUD only saves money
  if it stays well-utilized. Track *coverage* (how much of your floor is committed) and
  *utilization* (how much of the commitment you actually use); a 3-year commitment on a
  footprint that later shrinks is money lit on fire.
- **Reason on effective rates, not list prices.** Your real per-unit cost blends
  on-demand, committed, and spot, plus negotiated discounts. Decisions made on list
  price will be wrong.
- **The billing export is the source of truth.** Cloud providers stream detailed
  billing to a data warehouse (GCP → BigQuery, AWS → the Cost and Usage Report). Build
  dashboards and anomaly detection from that, not from screenshots of the console.
- **Commit to the floor, not the peak.** Commit only to capacity you are confident will
  run for the full term; cover everything above it with flexible on-demand and spot.
- **Account/project structure is an attribution tool.** Isolating teams or environments
  into their own projects gives you a clean split even before per-resource tagging.

---

## 7. Common mistakes

- **Modeling only the VM price.** The compute line looks like the whole bill, so
  storage, egress, load balancers, and managed services get ignored — then the invoice
  is 40% higher than the estimate. *Fix:* always model all four components; egress and
  storage first because they are the ones you'll forget.
- **Over-committing to today's peak.** Someone buys a 3-year CUD sized to a seasonal or
  one-off high, then the workload shrinks and the commitment keeps billing. *Fix:*
  commit to the stable floor; cover variable load flexibly.
- **Running stateful or critical work on spot.** Spot's discount is tempting, but a
  reclaim event kills the pod with ~30 seconds' notice. *Fix:* spot only for
  interruptible, retryable work, always with an on-demand fallback.
- **Untagged resources.** "We'll label things later" means a bill you can never split
  by owner. *Fix:* make labels mandatory at creation and enforce them (Module 18.3).
- **Treating a budget alert as a spend cap.** The email arrives *after* the money is
  spent and stops nothing. *Fix:* pair every budget with an action — automation or a
  named owner who responds.
- **Reasoning on list price.** Quoting the on-demand rate when half your fleet is
  committed or spot produces decisions that don't match reality. *Fix:* compute and use
  your blended effective rate.

---

## 8. Assessment

**Knowledge checks**

1. Write the one formula that every cloud charge reduces to, and name the four cost
   components it is summed over.
2. For each purchase option (on-demand, committed, spot), give the discount range and
   the one risk you accept in exchange.
3. Why does egress rarely show up in a naïve cost estimate, and name two architectural
   ways to reduce it.
4. A budget alert fires at 100%. Has your spending stopped? Explain.
5. Why can't an individual product team sensibly buy a Committed Use Discount, and who
   should?

**Concept exercise**

> Explain the difference between **committed** and **spot** capacity to a new engineer
> **without naming any cloud provider or product** — describe only the commitment, the
> discount, and the risk each one trades.

**Trade-off / debugging exercise**

> A team's monthly bill is \$1,200: \$700 compute, \$100 storage, \$400 egress. They
> ask you to cut it by moving to a cheaper instance type. Where is the real money, what
> would you investigate first, and what *non-compute* change might save more than any
> instance swap?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** `cost = Σ(rate × quantity × time) − discounts`, summed over **compute,
  storage, networking, and managed services**.
- **Q2:** On-demand — 0% discount, no risk but highest price. Committed — up to ~57%
  off, risk is paying for unused commitment for 1–3 years. Spot — 60–90% off, risk is
  reclamation with little notice.
- **Q3:** Ingress is free and egress is invisible while building; it only appears on the
  invoice. Reduce it by keeping traffic in-region / same-zone and by fronting static
  assets with a CDN (also: private interconnects, fewer cross-zone hops).
- **Q4:** No. A budget alert is a notification sent *after* spend crosses the threshold;
  it stops nothing. You need automation or a human to act.
- **Q5:** A single team sees only its own slice and can't safely commit the fleet's
  floor; the platform team, which sees aggregate steady usage, should own commitments.
- **Trade-off:** The real money is **egress (\$400, a third of the bill)**, not the
  instance type. Investigate *where* egress goes — cross-zone chatter, logs shipped to
  SaaS, un-cached assets — because an architectural fix there can beat any instance
  swap, which only touches the \$700 compute line.

</details>

---

## 9. Further reading

- FinOps Foundation — [What is FinOps / the Framework](https://www.finops.org/framework/)
- FinOps Foundation — [Unit Economics](https://www.finops.org/wg/unit-economics/)
- Google Cloud — [Committed Use Discounts](https://cloud.google.com/docs/cuds)
- Google Cloud — [Spot VMs](https://cloud.google.com/compute/docs/instances/spot) and [create and use budgets](https://cloud.google.com/billing/docs/how-to/budgets)
- Google Cloud — [Network pricing (egress)](https://cloud.google.com/vpc/network-pricing)
- AWS — [Pricing Calculator](https://calculator.aws/) (model before you build)
- OpenCost — [How cloud costs are modeled](https://www.opencost.io/docs/configuration/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 18 · FinOps overview](../README.md) · _Next:_ [Module 18.2 — Kubernetes Cost Management →](../02-kubernetes-cost-management/)
