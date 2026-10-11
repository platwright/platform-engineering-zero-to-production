<!-- markdownlint-disable MD033 -->
# Runbook — `<alert name>`

> Every alert links here via its `runbook_url`. Keep it short and actionable: an
> on-call engineer at 3am should be able to confirm, mitigate, and escalate from this
> page alone. Replace every `<placeholder>` and save as `runbook-<name>.md`.

## Summary

- **What fires this:** `<the alert condition, in plain language>`
- **Severity:** `<page / ticket>`
- **Owner / on-call:** `<team label, e.g. platform>`
- **Linked SLO:** `<which SLO / error budget this protects>`

## What this means

`<One short paragraph: what is actually wrong for users/teams when this fires, and why
it matters. Distinguish symptom from cause.>`

## How to confirm

1. `<first check — a dashboard link or PromQL/LogQL/TraceQL query>`
2. `<second check — is it real and sustained, or a blip?>`
3. `<scope — one tenant or everyone? which component?>`

## First mitigations

1. `<fastest safe action to reduce user impact — e.g. roll back the last sync, scale a
   component, fail over>`
2. `<second mitigation if the first does not help>`
3. `<what NOT to do (known footguns)>`

## Escalation

- If not mitigated within `<time>`, escalate to `<next on-call / owner>`.
- Declare an incident if `<condition, e.g. multiple teams blocked>`.
- Communications: `<where to post status, who to notify>`

## Related dashboards and queries

- Dashboard: `<link, e.g. grafana.example.com/d/platform-overview>`
- Key query: `<the PromQL/LogQL that quantifies the impact>`

## After the incident

- `<link the postmortem; update this runbook with anything you learned>`
- `<was the alert actionable and correctly routed? if not, tune it>`
