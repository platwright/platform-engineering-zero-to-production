<!-- markdownlint-disable MD033 -->
# Postmortem — <incident title>

> Blameless, structured, action-tracked. Examine systems and conditions, never
> individuals. Replace every `<...>` placeholder. Keep it factual and specific.

## Summary

- **Incident ID:** `<e.g. INC-2042>`
- **Date:** `<YYYY-MM-DD>`
- **Severity:** `<P0 / P1 / P2 / P3>`
- **Services affected:** `<e.g. Argo CD / GitOps sync>`
- **Teams impacted:** `<how many teams, which capability was blocked>`
- **Duration:** `<T0 to resolution, total minutes>`
- **Incident commander:** `<name/role>`
- **Authors:** `<names>`

One paragraph, plain language: what happened, who was affected, and how it was
resolved. Write it so a team lead who was not involved understands the impact.

`<summary paragraph>`

## Impact

- **User-facing impact:** `<e.g. all teams' deploys paused for 23 minutes>`
- **SLO / error budget:** `<which SLO burned, how much budget consumed>`
- **Data loss:** `<none / describe>`

## Timeline

> All times UTC. Record actions, observations, and decisions — the raw material for
> the contributing factors.

| Time (UTC) | Event |
|------------|-------|
| `<T0>` | `<detection — alert fired / symptom observed>` |
| `<...>` | `<triage — severity assigned, IC named>` |
| `<...>` | `<diagnosis — repo-server found offline>` |
| `<...>` | `<mitigation — repo-server restored>` |
| `<...>` | `<recovery verified — app Synced/Healthy, alert cleared>` |
| `<...>` | `<incident closed>` |

## Contributing factors

> Not "root cause" singular — incidents usually have several. Ask "why" until you
> reach a system/condition you can change.

- `<e.g. the repo-server ran a single replica, so one pod loss stopped all syncs>`
- `<e.g. the detecting alert had no runbook link, slowing the response>`
- `<e.g. there was no readiness-based auto-restart for the component>`

## What went well

- `<e.g. the burn-rate alert detected the outage within 2 minutes>`
- `<e.g. the runbook's mitigation step worked on the first try>`

## What went poorly / got lucky

- `<e.g. the IC was also running commands; comms to teams lagged>`

## Action items

> Every item has an **owner** and a **due date**, and is tracked to done like any
> other work. Prefer actions that remove the failure mode over actions that only
> speed up the next response.

| # | Action | Type (prevent/detect/mitigate) | Owner | Due | Status |
|---|--------|--------------------------------|-------|-----|--------|
| 1 | `<e.g. run argocd-repo-server with 2 replicas>` | prevent | `<name>` | `<date>` | open |
| 2 | `<e.g. add runbook: annotation to the SLO alerts>` | mitigate | `<name>` | `<date>` | open |
| 3 | `<e.g. add an auto-restart / PodDisruptionBudget>` | detect | `<name>` | `<date>` | open |

## Lessons

- `<one or two durable lessons for the team and for other platform services>`
