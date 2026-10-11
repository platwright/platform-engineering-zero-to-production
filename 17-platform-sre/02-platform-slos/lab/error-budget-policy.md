<!-- markdownlint-disable MD033 -->
# Platform error-budget policy

> Agree this **before** an incident. It defines what each burn tier means, who can
> declare a freeze, and how status reaches the teams that depend on the platform.
> Replace every `<...>` placeholder.

## Scope

- **Services covered:** GitOps sync latency, Argo CD availability, secret
  propagation, build pipeline (`<add others as you publish SLOs>`).
- **Window:** 30 days rolling.
- **Owner of this policy:** `<platform team / named role>`

## Per-service objectives

| Service | SLI (good ÷ valid) | Objective | Error budget |
|---------|--------------------|-----------|--------------|
| GitOps sync latency | syncs within 60s ÷ all syncs | 95% | 5% |
| Argo CD availability | API requests OK ÷ all | 99.9% | 0.1% |
| Secret propagation | ESO syncs OK ÷ all | 95% | 5% |
| Build pipeline | builds within 10m ÷ all | 95% | 5% |

## What each burn tier triggers

- **Fast burn (page) — the platform is actively failing teams.**
  - Declare a platform incident (Module 17.3) and page the on-call.
  - **Freeze risky changes to the platform** (upgrades, new defaults, controller
    changes). Decision owner: `<incident commander / platform lead>`.
  - Do **not** freeze teams' deploys unless the deploy path itself is the fault.
  - Communicate: `<status page banner + #platform-status channel post>`.

- **Slow burn (ticket) — a chronic drain.**
  - No page. Open a ticket and investigate within `<e.g. 1 business day>`.
  - Hold large/risky platform changes until the drain is understood.
  - Communicate: `<note in the weekly platform update>`.

- **Budget healthy.**
  - Ship platform changes freely; run chaos experiments (Module 17.5).

## Freeze rules

- **Who can declare a freeze:** `<role>`
- **Who can lift it:** `<role>` once budget burn returns below `<threshold>` for
  `<duration>`.
- **What a freeze blocks:** `<platform upgrades, addon rollouts, default changes>`
- **What a freeze never blocks:** `<stream teams' application deploys>`

## Communication plan

- **Status page / dashboard:** `<link>` shows current SLO and budget per service.
- **Proactive announcement:** on any freeze, post to `<channel>` within
  `<minutes>` with scope, impact, and expected duration.
- **Catalog:** each platform service lists its SLO in `<Backstage / service
  catalog>` so teams can set their own SLOs against it.

## Review

- This policy is reviewed `<quarterly>` and after every P0/P1 incident.
- A looser objective requires sign-off from `<role>` and a note to affected teams.
