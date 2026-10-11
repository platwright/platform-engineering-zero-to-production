# 18 · FinOps and Cost Engineering

> You can now build, ship, secure, and operate a platform. Every one of those
> capabilities runs on someone else's computer, and at the end of the month a bill
> arrives. This phase makes **cost a first-class, engineered property of the
> platform** — measured, attributed, and optimized the same way you treat latency
> or security. The hard part is not reading the invoice; it is answering *"which
> team, service, and decision caused this number?"* The cloud bill sees **nodes**;
> your platform sees **workloads**. Closing that gap is the whole discipline.

**Phase 14 · 5 modules · ~8–12 hours**

> FinOps baseline for this phase: the
> [FinOps Foundation Framework](https://www.finops.org/framework/) (Inform →
> Optimize → Operate) and the open-source
> [OpenCost specification](https://www.opencost.io/docs/specification). Keep both
> open — the lessons and labs map back to them throughout.

## Why this phase matters

Every prior phase quietly spent money. Requests and limits (Module 03.7) decided how
densely you pack nodes — and nodes are the unit the cloud charges for. Autoscaling
decided how many nodes you run. Storage, load balancers, and cross-zone traffic all
accrued charges you never saw, because nobody was watching the bill while building
the platform. That is normal, and it is also how organizations wake up to a cloud
spend that doubled while "nothing changed."

Platform engineering answers cost **structurally**, exactly as it answered security.
Instead of asking every product team to become a billing analyst, the platform makes
cost *visible by default* — attributed to the team that caused it, reported on a
cadence, and optimized through the paved road rather than through heroics. This is
the course's recurring theme made concrete: **security and cost are structural, not
bolt-on.** A platform that cannot tell you who spent what is as unfinished as one
that cannot tell you who can access what.

The central problem is **attribution**, and it exists because of a representation
mismatch:

```text
   What the cloud bill sees            What the platform sees
   ────────────────────────            ──────────────────────
   3 × n2-standard-8 nodes      ??     namespace: team-payments  (12 pods)
   1 × regional load balancer    │     namespace: team-search    (30 pods)
   2 TB egress to the internet   │     namespace: team-web       (8 pods)
   500 GB SSD persistent disk    │     namespace: platform       (ingress, logging)
            │                     │              │
            ▼                     ▼              ▼
      ONE invoice, priced     the gap      MANY owners, priced
      per node & resource   (this phase)   per workload & team
```

A node runs pods from several teams at once. The invoice knows the node cost but not
the split; the cluster knows the split but not the cost. FinOps tooling joins the
two — multiplying each node's price by each workload's share of it — so that a line
item on the invoice becomes a number a specific team can own and act on.

This phase gives you the model and the tools to do that:

- **Make cost visible.** You cannot optimize what you cannot see. OpenCost turns node
  prices and pod requests into a cost-per-workload figure, in Grafana, for free.
- **Attribute it to owners.** Mandatory cost labels — enforced with Kyverno, the same
  engine you used for the security baseline — turn anonymous spend into a per-team
  bill you can show (showback) or charge (chargeback).
- **Optimize through the paved road.** Right-sizing, spot capacity, bin-packing, and
  scale-to-zero are platform capabilities teams inherit, not projects each team runs.
- **Operate it as a practice.** FinOps is a culture — unit economics, cost reviews,
  and anomaly alerting — shared across platform and engineering, not a quarterly
  panic.

You have already built every prerequisite. Module 03.7 set the requests and limits
that *drive* cost. Project 1 required ownership and cost labels on every workload.
Module 13.3 gave you the policy engine to enforce them. Project 3 gave you the Grafana
in which cost dashboards live. This phase ties them into one coherent, engineered
answer to *"what does this platform cost, and who pays for it?"*

## The FinOps loop

The discipline is a continuous loop, not a one-time cleanup. You will recognize it as
the same shape as an observability or SRE feedback loop, applied to money:

```text
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
   ┌─────────┐        ┌──────────┐        ┌──────────┐             │
   │  INFORM  │ ─────▶ │ OPTIMIZE │ ─────▶ │  OPERATE  │ ───────────┘
   └─────────┘        └──────────┘        └──────────┘
   visibility &        right-size,         governance,
   attribution         spot, bin-pack,     anomaly alerts,
   (18.1–18.3)         scale-to-zero       cost reviews
                       (18.4)              (18.5)
   "what does it       "spend less for     "keep it that way
    cost, and who       the same value"     as the org grows"
    owns it?"
```

Inform comes first and is non-negotiable: optimization without attribution is
guessing, and governance without data is politics. The modules below walk the loop in
order.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 87 | [Cloud Cost Fundamentals](./01-cloud-cost-fundamentals/) | Pricing models (on-demand / committed / spot); cost components; CUDs; egress; allocation tags; billing hierarchy, budgets, alerts. | A completed cost-model worksheet comparing on-demand, committed, and spot for a reference cluster. |
| 88 | [Kubernetes Cost Management](./02-kubernetes-cost-management/) | The attribution gap; the cost-per-workload formula; idle cost; node efficiency; OpenCost and Kubecost; cost in Grafana. | OpenCost on kind, allocation queried by namespace, top-5 costly and idle workloads identified. |
| 89 | [Cost Attribution and Chargeback](./03-cost-attribution/) | Showback vs chargeback; mandatory cost labels; enforcing labels with Kyverno; team cost dashboards; a weekly Slack report. | An enforced `require-cost-labels` policy plus a per-team weekly cost report. |
| 90 | [Cost Optimization Patterns](./04-cost-optimization-patterns/) | Right-sizing with VPA; spot for non-critical; Karpenter bin-packing and consolidation; scale-to-zero; storage tiering; egress; deleting idle resources. | Three measured optimizations: right-sizing from VPA, scale-to-zero, and a consolidation/spot plan. |
| 91 | [FinOps Culture and Process](./05-finops-culture-and-process/) | The Inform → Optimize → Operate lifecycle; unit economics; the cost / quality / reliability triangle; cost reviews; anomaly alerting; governance. | A completed FinOps process worksheet with a unit-economics metric and an anomaly-alert threshold. |

Work them in order — each builds on the last. Together they take you from "how is
cloud priced?" to "here is an attributed, optimized, continuously governed cost
practice every team participates in."

## Learning objectives

By the end of this phase you will be able to:

- Explain the **three cloud purchase options** (on-demand, committed, spot) and the
  cost components (compute, storage, network, managed services), and choose the right
  mix for a workload's risk profile.
- Describe the **Kubernetes attribution gap** and compute a **cost per workload** from
  node price and resource requests, including **idle cost** and **node efficiency**.
- Stand up **OpenCost** on a cluster, query allocation by namespace and workload, and
  surface the data in **Grafana**.
- Enforce **mandatory cost labels** with Kyverno and build a **showback** report,
  then reason about when (and whether) to move to **chargeback**.
- Apply the core **optimization patterns** — right-sizing, spot, bin-packing /
  consolidation, scale-to-zero, storage tiering, egress reduction, idle cleanup — and
  **measure** the savings.
- Run FinOps as a **practice**: unit economics, the cost / quality / reliability
  trade-off, cost reviews, anomaly detection, and platform-level governance.

## Prerequisites

- [Module 03.7 · Resource Management](../03-kubernetes-fundamentals/07-resource-management/) —
  requests, limits, quotas, HPA/VPA. **Cost is downstream of these.** This phase
  assumes you can read and set them.
- [Module 13.3 · Policy as Code with Kyverno](../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/) —
  you reuse Kyverno here to enforce cost labels.
- [Phase 11 · Observability Engineering](../11-observability-engineering/) and
  [Project 3](../12-platform-project-03/) — Prometheus and Grafana, where cost
  dashboards and anomaly alerts live.
- [Project 1](../04-platform-project-01/) — the golden path that first required
  ownership and cost labels; this phase makes those labels pay off.
- A local toolchain: Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), and
  [Helm](https://helm.sh/) — each lab installs what it needs on top.

## A note on cost

Every required lab in this phase runs **free** on a local kind cluster. OpenCost
produces **estimated** costs on kind using its built-in default price list, so you can
practice attribution and optimization with no cloud account. Where a step depends on
real cloud billing — Committed Use Discounts, live spot prices, actual dollar figures,
or a cloud provider's pricing API — it is clearly marked **optional** with an
accounts-and-cost note, and a local equivalent keeps the core exercise free. You never
need to spend a cent to complete the required path, which is itself a FinOps lesson:
*model the cost before you incur it.*

---

Start with [**87 · Cloud Cost Fundamentals →**](./01-cloud-cost-fundamentals/)
