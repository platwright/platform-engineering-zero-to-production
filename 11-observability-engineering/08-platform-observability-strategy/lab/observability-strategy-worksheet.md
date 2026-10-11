<!-- markdownlint-disable MD033 -->
# Platform observability strategy worksheet

Fill in each `<placeholder>`. The guiding question throughout: **whose 3am is this?**
If a signal's failure wakes the platform on-call, the platform owns it; if it wakes one
team, that team does; if everyone should *see* it but no one is paged, it is shared.

## Part A — Ownership classification

Classify each signal as **platform**, **shared** (published to all teams, paged by
no one), or **app**. Give the deciding reason.

| Signal | Owner (platform / shared / app) | Whose 3am? / why |
|--------|---------------------------------|------------------|
| Argo CD sync success rate | `<owner>` | `<why>` |
| A single service's p99 latency | `<owner>` | `<why>` |
| Cluster API server error rate | `<owner>` | `<why>` |
| Per-namespace CPU usage | `<owner>` | `<why>` |
| External Secrets Operator reconcile errors | `<owner>` | `<why>` |
| Prometheus TSDB active series (cardinality) | `<owner>` | `<why>` |
| One team's error budget burn | `<owner>` | `<why>` |
| etcd commit latency | `<owner>` | `<why>` |

## Part B — Golden signals for platform services

| Platform service | Signal(s) you track | Failure it catches |
|------------------|---------------------|--------------------|
| Argo CD | `<signal>` | `<failure>` |
| Prometheus / Mimir | `<signal>` | `<failure>` |
| Grafana | `<signal>` | `<failure>` |
| External Secrets Operator | `<signal>` | `<failure>` |
| OTel Collector | `<signal>` | `<failure>` |

## Part C — Cluster control-plane signals

| Component | Signal | Why the platform owns it |
|-----------|--------|--------------------------|
| API server | `<signal>` | `<why>` |
| etcd | `<signal>` | `<why>` |
| Nodes | `<signal>` | `<why>` |
| Scheduler | `<signal>` | `<why>` |
| Capacity (requests vs allocatable) | `<signal>` | `<why>` |

## Part D — Paging and routing policy

| Alert | Page or Ticket | Routes to (team label) | Grouping / silence notes |
|-------|----------------|------------------------|--------------------------|
| Argo CD sync error budget burning fast | `<page/ticket>` | `<team>` | `<notes>` |
| API server latency SLO breach | `<page/ticket>` | `<team>` | `<notes>` |
| A team's service error budget burn | `<page/ticket>` | `<team>` | `<notes>` |
| Node fleet losing capacity | `<page/ticket>` | `<team>` | `<notes>` |
| OTel Collector dropping telemetry | `<page/ticket>` | `<team>` | `<notes>` |

## Part E — Worst single outage

> Which single platform-service failure would hurt the most teams, and what SLO do you
> set for it? Justify the target.

- Worst outage: `<service>`
- Why it hurts most: `<reasoning>`
- SLO target: `<e.g. 99.9%>` because `<justification>`
