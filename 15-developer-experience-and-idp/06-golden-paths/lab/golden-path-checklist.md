<!-- markdownlint-disable MD033 -->
# Golden-Path Readiness Checklist

> Fill in each section for one golden path. Replace every `<placeholder>`. A path is
> **not ready** until every "by default" box is checked. Reuse this for each path your
> platform offers.

- **Golden path name:** `<e.g. standard Go service>`
- **Version:** `<e.g. v1>`
- **Owner:** `<team>` · **Support channel:** `<#channel>`
- **Author / date:** `<name>` / `<yyyy-mm-dd>`

## 1. Must-include capabilities

> Mark each **Default** (wired in automatically) or **Opt-in** (developer must act).
> Every Opt-in is a gap — record the fix.

| Capability | How this path provides it | Default or opt-in? | Fix if opt-in |
|------------|---------------------------|--------------------|---------------|
| Repository scaffold | `<template name>` | `<default/opt-in>` | `<fix>` |
| CI/CD pipeline | `<reusable workflow @tag>` | `<default/opt-in>` | `<fix>` |
| Container build + push | `<Dockerfile + registry>` | `<default/opt-in>` | `<fix>` |
| IaC for cloud resources | `<Terraform/Crossplane>` | `<default/opt-in>` | `<fix>` |
| GitOps deployment config | `<ArgoCD Application>` | `<default/opt-in>` | `<fix>` |
| Observability (OTel + dashboard) | `<SDK + dashboard template>` | `<default/opt-in>` | `<fix>` |
| Security (non-root, signed, SBOM) | `<controls>` | `<default/opt-in>` | `<fix>` |
| Documentation (TechDocs) | `<docs skeleton>` | `<default/opt-in>` | `<fix>` |

## 2. Escape hatch

- **Legitimate deviation the path must allow:** `<e.g. custom base image>`
- **How it is documented:** `<where the request process lives>`
- **How it is reviewed:** `<label + sign-off? who approves?>`
- **How it is visible/counted:** `<logged where; shows up in which report>`
- **Signal to fold it into the default path:** `<e.g. used by >3 teams>`

## 3. Versioning and migration

- **Version scheme:** `<e.g. v1, v1.1, v2 — moving major tag>`
- **Deprecation policy:** `<old version warns + sunset date>`
- **Migration tooling (not just a guide):** `<bot/codemod that opens the bump PR>`
- **Sunset window:** `<e.g. 90 days>`

## 4. Adoption metrics

| Metric | Target | Source |
|--------|--------|--------|
| Coverage (% prod services on a path) | `<target>` | `<catalog query>` |
| Version adoption (% on current version) | `<target>` | `<catalog/CI telemetry>` |
| Escape-hatch rate | `<target>` | `<CI/exception report>` |
| Time-to-first-production-deployment | `<e.g. < 1 day>` | `<measured how>` |

## 5. Contract

- **Reliability / SLO:** `<platform SLO for this path>`
- **Interface stability promise:** `<versioned; no breaking changes without a major>`
- **Support:** `<channel, office hours, response expectation>`

---

### Readiness verdict

- [ ] Every must-include capability is **default**, not opt-in.
- [ ] The escape hatch is documented, reviewed, and counted.
- [ ] There is real migration **tooling**, not just a guide.
- [ ] Adoption metrics are defined with real sources.
- [ ] The contract (SLO, stability, support) is published.

**Verdict:** `<READY / NOT READY — list blockers>`
