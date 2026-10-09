<!-- markdownlint-disable MD033 -->
# IDP Capability Assessment

> Copy and fill in. Be honest — a flattering assessment helps no one.

**Assessor:** <name> · **Date:** <YYYY-MM-DD>
**Organization:** <real org / "HelloCorp" fictional> · **~Engineers / services:** <n / n>

**Legend:** 🟢 self-service · 🟡 ticket-driven · 🔴 absent / ad hoc

---

## Core capabilities

| Capability | Rating | Evidence (how it works today) | Pain it causes |
|------------|:------:|-------------------------------|----------------|
| Self-service provisioning (new service/resource) | 🔴🟡🟢 | | |
| Environment management (dev/staging/preview/prod) | 🔴🟡🟢 | | |
| Application catalog (what exists, who owns it) | 🔴🟡🟢 | | |
| Deployment automation | 🔴🟡🟢 | | |
| Secrets management | 🔴🟡🟢 | | |
| Observability (metrics/logs/traces/cost) | 🔴🟡🟢 | | |
| Access control (least privilege) | 🔴🟡🟢 | | |

_(Keep one rating per row; the others are just the options.)_

## Five planes

| Plane | What exists today | What's missing | Default or bolted-on? |
|-------|-------------------|----------------|-----------------------|
| Developer control plane (portal/CLI/API) | | | |
| Integration & delivery (CI/CD, GitOps) | | | |
| Resource plane (clusters, DBs, IaC) | | | |
| Monitoring plane (observability, cost) | | | |
| Security plane (identity, secrets, policy) | | | |

## Summary

- **Overall maturity (your call):** <e.g. "mostly ticket-driven; thin control plane">
- **Weakest plane:** <…> — why: <…>
- **Is security/monitoring default or afterthought?** <…>

## Biggest gap & thin next step

- **Biggest gap:** <capability/plane> — moving it to 🟢 would help because <…>
  (ties to discovery finding: <…>).
- **Thinnest valuable next step (TVP):** <the smallest build/buy move> — because <…>.
- **Build / buy / adopt:** <which, and why>.

## Reflection

- Count of 🟢 vs 🟡 vs 🔴: <…>
- Does this next step match my Module 01.2 brief? <…>
