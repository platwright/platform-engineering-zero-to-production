<!-- markdownlint-disable MD033 -->
# Toil inventory worksheet

> Fill this in for one week (or one sprint). Classify each task, quantify the toil,
> compute the fraction, then rank and turn it into an automation backlog. A worked
> fictional scenario is provided first so you can complete the lab solo; a blank
> template for your own team follows.

Replace every `<...>` placeholder with your own values.

## The six-point toil test

A task is **toil** when it is all of these. If it fails any, lean toward
"engineering".

- **Manual** — a human performs it.
- **Repetitive** — done before, will be done again.
- **Automatable** — a machine could do it.
- **Reactive / tactical** — interrupt-driven, not strategic.
- **No enduring value** — the service is no better after than before.
- **O(n) with growth** — scales with teams, traffic, or services.

## Part A — Worked scenario (fill in the classification)

A 4-person platform team logs one week. Available time ≈ 4 engineers × 30 productive
hours = **7200 minutes**. Classify each task and compute `toil-minutes`.

| Task | Minutes each | Times this week | Toil or engineering? | Reason | Toil-minutes |
|------|--------------|-----------------|----------------------|--------|--------------|
| Create namespace + RBAC + quotas for a new team | 20 | 9 | `<toil/eng>` | `<reason>` | `<n>` |
| Create/rotate a secret by hand after a leak | 15 | 4 | `<toil/eng>` | `<reason>` | `<n>` |
| Restart a stuck External Secrets Operator pod | 10 | 7 | `<toil/eng>` | `<reason>` | `<n>` |
| Manually renew + redeploy a TLS certificate | 25 | 3 | `<toil/eng>` | `<reason>` | `<n>` |
| Approve + apply an access (RBAC) request | 12 | 10 | `<toil/eng>` | `<reason>` | `<n>` |
| Drain nodes + click through a cluster upgrade | 90 | 1 | `<toil/eng>` | `<reason>` | `<n>` |
| Write the runbook for that upgrade | 120 | 1 | `<toil/eng>` | `<reason>` | `<n>` |
| Debug a novel CNI/MTU incident | 180 | 1 | `<toil/eng>` | `<reason>` | `<n>` |
| Build a GitOps "new team" generator (project work) | 240 | 1 | `<toil/eng>` | `<reason>` | `<n>` |

Suggested answers (classify first, then check your reasoning):

- Namespace/RBAC onboarding, secret rotation, operator restarts, cert renewal, and
  access requests are **toil** — manual, repetitive, automatable, O(n) with growth.
- The upgrade *run* is toil; writing the *runbook*, debugging a *novel* incident, and
  building the generator are **engineering** (they leave lasting value behind).

## Part B — Totals and the toil fraction

- **Total toil-minutes this week:** `<sum of the toil rows>`
- **Available minutes:** `4 × 30 × 60 = 7200`
- **Toil fraction:** `<toil-minutes> / 7200 = <0.xx>` → `<xx>%`
- **Healthy?** Compare to the ~50% cap: `<yes / no — over budget>`

```bash
# compute the fraction (replace TOIL_MINUTES)
echo "scale=3; TOIL_MINUTES / 7200" | bc
```

## Part C — Ranked automation backlog

Sort the toil categories by **total minutes (cost)**, highest first, and name the
automation that removes each. Map to something you already built where possible.

| Rank | Toil category | Minutes/week | Automation that removes it | Est. weekly saving |
|------|---------------|--------------|----------------------------|--------------------|
| 1 | `<e.g. namespace + RBAC onboarding>` | `<n>` | `<GitOps templates / a "new team" generator>` | `<n>` |
| 2 | `<e.g. operator restarts>` | `<n>` | `<liveness probe + runbook, then an operator>` | `<n>` |
| 3 | `<e.g. secret rotation>` | `<n>` | `<External Secrets Operator (Module 13.4)>` | `<n>` |
| 4 | `<e.g. cert renewal>` | `<n>` | `<cert-manager>` | `<n>` |
| 5 | `<e.g. access requests>` | `<n>` | `<self-service + policy as code>` | `<n>` |

**Top automation to build next (with its hours justification):**

`<one or two sentences: which item, how many hours/week it frees, and why it ranks
first — remember to weight critical-path services by how many teams a failure blocks>`

## Part D — Your real team (optional)

Repeat Parts A–C with one real sprint of your own team's work.

| Task | Minutes each | Times this sprint | Toil or engineering? | Reason | Toil-minutes |
|------|--------------|-------------------|----------------------|--------|--------------|
| `<task>` | `<n>` | `<n>` | `<toil/eng>` | `<reason>` | `<n>` |
| `<task>` | `<n>` | `<n>` | `<toil/eng>` | `<reason>` | `<n>` |
| `<task>` | `<n>` | `<n>` | `<toil/eng>` | `<reason>` | `<n>` |

- **Toil fraction this sprint:** `<0.xx>` → `<xx>%`
- **Trend vs last sprint:** `<up / down / flat>`
- **Next automation to build:** `<item>`
