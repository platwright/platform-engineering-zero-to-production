<!-- markdownlint-disable MD033 -->

# Global load-balancing design worksheet

Fill in every `<placeholder>`. This one page is a global front-door design an on-call team
could operate: the data model (chosen first), the routing and health policy, and a failover
runbook. Keep it with your SLO document — availability and routing are decided together.

## 0. Scenario

| Field | Your answer |
|-------|-------------|
| System | `<name / description>` |
| User regions | `<e.g. EU + US (+ APAC?)>` |
| Read/write mix | `<e.g. write-heavy / read-heavy>` |
| Availability target (SLO) | `<e.g. 99.95%>` |
| Target RTO (time to recover) | `<e.g. < 1 minute>` |
| Target RPO (tolerable data loss) | `<e.g. ~0 / a few minutes>` |

## 1. Data model (decide this FIRST)

| Question | Your answer |
|----------|-------------|
| Can writes land in more than one region at once? | `<yes / no>` |
| Do you NEED multi-region writes for your RTO/RPO? | `<yes / no>` |
| Chosen model | `<active-active / active-passive>` |
| One-sentence justification FROM THE DATA | `<...>` |
| Data layer that makes it work | `<e.g. shard by home region / multi-primary DB / single primary + async replica>` |
| Split-brain / conflict handling (if active-active) | `<...>` |

## 2. Routing

| Field | Your answer |
|-------|-------------|
| Routing type | `<latency / geo / weighted / failover>` |
| Mechanism | `<anycast / DNS>` |
| If DNS: TTL and the failover delay it implies | `<e.g. 30s TTL → up to ~30s stale>` |
| Data-residency constraints on routing | `<e.g. EU users must stay in EU>` |

Per-region routing table:

| Region | Backend | Priority (equal = active-active) | Health path |
|--------|---------|----------------------------------|-------------|
| `<eu-west>` | `<lb-eu>` | `<1>` | `<healthz>` |
| `<us-east>` | `<lb-us>` | `<1 or 2>` | `<healthz>` |
| `<optional 3rd>` | `<...>` | `<...>` | `<...>` |

## 3. Health checks and failover

| Field | Your answer |
|-------|-------------|
| What makes a region "healthy" (DEEP check) | `<app up AND datastore reachable AND ...>` |
| Check interval / unhealthy threshold | `<e.g. every 10s, 3 consecutive fails>` |
| What happens automatically on unhealthy | `<region removed from rotation / standby promoted>` |
| Expected real RTO | `<...>` |
| RPO exposure at failover | `<...>` |
| How flapping is prevented | `<thresholds / hysteresis / cooldown>` |

## 4. Edge

| Question | Your answer |
|----------|-------------|
| What runs at the edge (if anything)? | `<auth / caching / A/B / redirects / nothing>` |
| What you deliberately keep OUT of the edge | `<core logic, authoritative state, ...>` |
| How edge logic is versioned and observed | `<...>` |

## 5. Failover runbook

Write the procedure an on-call engineer follows (or verifies, if automatic) when a region
fails:

> 1. `<detect: what signals the failure>`
> 2. `<routing: what reroutes, automatically or manually>`
> 3. `<data: promote / confirm replica / reconcile>`
> 4. `<verify: how you confirm users are served from the healthy region>`
> 5. `<recover: how the failed region re-enters rotation safely>`

## 6. Game-day test

| Field | Your answer |
|-------|-------------|
| What you fail on purpose | `<e.g. blackhole region EU's backend>` |
| What you measure | `<observed RTO, RPO, error rate>` |
| Success criteria | `<e.g. RTO < 1 min, zero data loss, auto-recovery>` |
| The thing most likely to break first | `<your honest prediction>` |
| Cadence | `<e.g. quarterly>` |

## 7. One-paragraph summary

> `<Why, for this design, losing a whole region is a routing event rather than an outage —
> and the single biggest risk you are carrying into the first real failover.>`
