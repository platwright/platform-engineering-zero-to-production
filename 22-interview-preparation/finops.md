# Interview Prep — FinOps and Cost Engineering

> This domain tests whether you can make cost a first-class engineering signal:
> attribute it, optimize it, and build a culture around it. Interviewers probe
> pricing models, the attribution gap, OpenCost, label enforcement, right-sizing,
> spot, and showback versus chargeback. Practice tying every lever back to **unit
> economics** out loud before reading the model answer.

## Cloud economics

### Q: What are the main cloud pricing models?

**What they're really asking:** Do you know how to blend commitment, flexibility, and risk?

- **On-demand** — pay per second/hour, no commitment; most flexible and most expensive, for spiky or unpredictable load.
- **Reserved Instances** — commit one to three years to a family/region for a large discount; least flexible.
- **Savings Plans** — commit to a dollars-per-hour spend for one to three years; more flexible than RIs across families.
- **Spot** — spare capacity at up to ~90% off, but **reclaimable with about two minutes' notice**; for fault-tolerant, interruptible work.

The usual strategy: cover the steady **baseline with commitments**, **burst on
on-demand**, and run **interruptible workloads on spot**.

**Going deeper:** [18.1 · Cloud Cost Fundamentals](../18-finops-and-cost-engineering/01-cloud-cost-fundamentals/)

**Red flags:** Running a stable 24/7 baseline entirely on on-demand, or putting a stateful database on spot.

### Q: What is the cost attribution gap in a shared cluster?

**What they're really asking:** Do you understand why the cloud bill cannot tell you who spent what?

The cloud invoice is billed **per node and per resource**, but a shared multi-tenant
cluster runs many teams' pods on the **same nodes** — so the bill cannot say which team
or service drove the cost. That mismatch between **invoice granularity** and
**team/service granularity** is the attribution gap. Kubernetes cost tools close it by
allocating each node's cost down to pods (by their resource requests/usage and labels).
It also exposes **idle/unallocated** cost — the gap between provisioned and used
capacity — which someone must own.

**Going deeper:** [18.2 · Kubernetes Cost Management](../18-finops-and-cost-engineering/02-kubernetes-cost-management/) and [18.3 · Cost Attribution and Chargeback](../18-finops-and-cost-engineering/03-cost-attribution/)

### Q: What is unit economics, and why does it matter more than total spend?

**What they're really asking:** Do you connect cost to business value with a denominator?

Unit economics is cost per **meaningful business unit** — per customer, per request,
per transaction, per team. Absolute spend is close to meaningless without a
denominator: a million dollars is healthy at ten million customers and alarming at one
hundred. Unit cost tells you whether you get **more efficient as you scale** and ties
engineering decisions to business value. The target is flat or **declining unit cost**
as the business grows.

**Going deeper:** [18.1 · Cloud Cost Fundamentals](../18-finops-and-cost-engineering/01-cloud-cost-fundamentals/) and [18.5 · FinOps Culture and Process](../18-finops-and-cost-engineering/05-finops-culture-and-process/)

**Red flags:** Reporting only total monthly spend with no per-unit or per-team denominator.

## Attribution and reporting

### Q: How does OpenCost work?

**What they're really asking:** Do you know how Kubernetes cost allocation is actually computed?

**OpenCost** is the CNCF open-source standard for Kubernetes cost monitoring (the spec
behind Kubecost). It takes the cloud's **node and resource prices**, then distributes
each node's cost across the pods running on it based on their **resource requests and
usage** (CPU, memory, GPU, plus persistent volumes and network), aggregated by
**labels and namespaces**. The output is cost per namespace, team, or service — the
raw material for showback — and it surfaces **idle/unallocated** cost. Because it
aggregates by **pod** labels, your labels must be present on the pod template.

**Going deeper:** [18.2 · Kubernetes Cost Management](../18-finops-and-cost-engineering/02-kubernetes-cost-management/)

### Q: How do you enforce cost labels, and why use Kyverno?

**What they're really asking:** Do you make attribution trustworthy rather than hope teams tag things?

Attribution depends on a consistent **label taxonomy** — team, app, environment,
cost-center — which is the contract that makes allocation possible. Voluntary labels
drift, so you **enforce** them with policy as code: a **Kyverno** admission policy
**requires** the labels on workloads (reject if missing, or mutate to add safe
defaults). The labels must land on the **pod template**, since OpenCost aggregates by
pod labels. Enforcement at admission is what turns attribution from "best effort" into
"reliable."

**Going deeper:** [18.3 · Cost Attribution and Chargeback](../18-finops-and-cost-engineering/03-cost-attribution/) and [13.3 · Policy as Code with Kyverno](../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/)

**Red flags:** Relying on a wiki page asking teams to "please add labels," then wondering why 40% of cost is unallocated.

### Q: Showback versus chargeback — what is the difference and the right sequence?

**What they're really asking:** Do you know you must earn trust before billing teams?

**Showback** shows each team its cost for **visibility** — no money moves. **Chargeback**
actually **bills** the cost back to the team's budget. The sequence matters: **start
with showback**, prove the numbers are accurate and reconcile with the cloud invoice,
and only then graduate to chargeback. Jumping to chargeback on shaky attribution
destroys credibility the first time a team is billed for cost it does not recognize.
Showback changes behavior through transparency; chargeback adds financial
accountability once the data is trusted.

**Going deeper:** [18.3 · Cost Attribution and Chargeback](../18-finops-and-cost-engineering/03-cost-attribution/)

**Red flags:** Launching chargeback on day one, before attribution is accurate and reconciled.

## Optimization and process

### Q: How do you right-size workloads?

**What they're really asking:** Do you know the biggest, safest Kubernetes cost lever?

Right-sizing means matching **resource requests** to actual usage. Teams over-request
"to be safe," so requested far exceeds used, utilization drops, and you pay for
capacity nobody uses. Use real usage data — VPA recommendations, OpenCost, metrics — to
lower requests toward true p95/p99 usage plus headroom. Because **requests drive
scheduling and therefore node count**, right-sizing them is the largest and safest cost
lever. The caution: do not starve bursty or latency-sensitive workloads.

**Going deeper:** [18.4 · Cost Optimization Patterns](../18-finops-and-cost-engineering/04-cost-optimization-patterns/)

**Red flags:** Setting requests equal to limits at inflated "just in case" values across the fleet.

### Q: When and how do you use spot instances?

**What they're really asking:** Do you know which workloads tolerate reclamation and how to handle it?

Use spot for **fault-tolerant, stateless, interruptible, replicable** workloads — batch
jobs, CI, dev, and stateless services with enough replicas. Handle interruptions:
spread across **instance types and AZs** to avoid correlated reclamation, honor the
**two-minute termination notice** by draining gracefully, protect availability with
**PodDisruptionBudgets**, let **Karpenter** diversify, and keep stateful or critical
workloads on on-demand or reserved capacity.

**Going deeper:** [18.4 · Cost Optimization Patterns](../18-finops-and-cost-engineering/04-cost-optimization-patterns/)

**Red flags:** Putting a database or a singleton with no replicas on spot and being surprised by data loss.

### Q: What is consolidation, and how does Karpenter consolidation help?

**What they're really asking:** Do you understand node-level bin-packing, not just pod requests?

Consolidation is packing pods densely onto fewer nodes to raise utilization and cut
cost. **Karpenter consolidation** continuously looks to **remove or replace** nodes —
delete empty or underused nodes and re-pack their pods, or swap for a cheaper,
right-sized instance — so you stop paying for fragmented, half-empty nodes. It is the
runtime complement to right-sizing: **right-sizing fixes requests; consolidation fixes
node packing.** Use disruption controls (PodDisruptionBudgets, do-not-disrupt
annotations) so it does not harm availability.

**Going deeper:** [18.4 · Cost Optimization Patterns](../18-finops-and-cost-engineering/04-cost-optimization-patterns/) and [17.4 · Platform Capacity Planning](../17-platform-sre/04-platform-capacity-planning/)

### Q: What is the FinOps lifecycle?

**What they're really asking:** Do you treat FinOps as a continuous culture, not a one-off cleanup?

The FinOps Foundation defines three iterative phases:

- **Inform** — visibility and allocation (showback): know where the money goes.
- **Optimize** — right-size, buy commitments, use spot, consolidate: reduce it.
- **Operate** — govern continuously with policy, automation, and culture: make it a habit.

It is a cumulative loop and a **cultural** practice that brings finance, engineering,
and product together — engineers taking **cost ownership** is the whole point — not a
quarterly cost-cutting scramble.

**Going deeper:** [18.5 · FinOps Culture and Process](../18-finops-and-cost-engineering/05-finops-culture-and-process/)

**Red flags:** Treating cost as finance's problem, or doing a one-time cleanup with no ongoing governance.
