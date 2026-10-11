<!-- markdownlint-disable MD033 -->

# FinOps process worksheet

Fill in every `<placeholder>`. This one page is your team's **operating model** for the
Operate phase: how you measure, review, alert on, and govern cost. Keep it next to your
SLO document — cost and reliability are set on the same console.

## 1. Lifecycle position

| Question | Your answer |
|----------|-------------|
| Where is this team today — Crawl / Walk / Run? | `<crawl / walk / run>` |
| What's in place already (tags, showback, right-sizing…)? | `<...>` |
| The single next practice to adopt | `<e.g. weekly report, VPA right-sizing, anomaly alert>` |

## 2. Unit economics

Pick the business denominator that best reflects what this service *does*.

| Field | Value |
|-------|-------|
| Service | `<service name>` |
| Business unit (denominator) | `<per 1,000 requests / per active user / per order / per tenant>` |
| Cost this period | `$<cost>` |
| Business units this period | `<count>` |
| **Unit cost** = cost ÷ units | `$<result>` |
| Trend vs last period | `<up / down / flat> <by X%>` |
| Is this *good* or *bad* cost, and why? | `<does it scale with value or with waste?>` |

## 3. Anomaly alert

| Field | Value |
|-------|-------|
| Signal to watch | `<cluster cost / per-team cost / unit cost>` |
| Threshold | `<e.g. > 20% week-over-week>` |
| Evaluation window / `for` | `<e.g. sustained 30m>` |
| Routes to (owning team/channel) | `<team + channel>` |
| How false positives are handled (launches, seasonality) | `<...>` |

## 4. Review cadence

| Cadence | What is reviewed | Who attends |
|---------|------------------|-------------|
| Weekly | `<per-team report: trend + top services>` | `<team>` |
| Monthly | `<unit economics + anomalies + SLOs>` | `<team + platform>` |
| Quarterly | `<commitment (CUD) coverage + forecast>` | `<platform + finance>` |

## 5. Governance guardrails

Three defaults that keep the efficient path the easy path. Map each to a mechanism.

| Guardrail | Mechanism / tool |
|-----------|------------------|
| `<every workload is attributable>` | `<Kyverno require-cost-labels (18.3)>` |
| `<no resource-less or unbounded workloads>` | `<LimitRange + ResourceQuota (03.7)>` |
| `<teams can only pick sane node types>` | `<approved instance-type list / policy>` |

## 6. The cost / reliability / velocity triangle

Place two workloads and state the trade each one makes **on purpose**.

| Workload | Corner it sacrifices | Why that's correct |
|----------|----------------------|--------------------|
| `<e.g. payments API>` | `<cost>` | `<buys reliability: headroom, on-demand, replicas>` |
| `<e.g. nightly batch>` | `<velocity / latency>` | `<buys low cost: spot, tight requests>` |

## 7. Ownership

- Who **informs** (owns visibility & attribution): `<platform>`
- Who **optimizes** (owns their spend & right-sizing): `<each team>`
- Who **operates** (owns governance, forecast, commitments): `<platform + finance>`
- One sentence on how this stays *enablement*, not *policing*: `<...>`
