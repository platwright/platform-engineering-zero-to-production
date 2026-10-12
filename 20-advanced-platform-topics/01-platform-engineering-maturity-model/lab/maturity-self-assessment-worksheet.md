<!-- markdownlint-disable MD033 -->
# Platform Maturity Self-Assessment

> Copy and fill in. Grade what you can **defend with evidence**, not what you aspire
> to. When unsure between two levels, choose the lower one. Report the profile, not a
> single averaged score.

**Assessed by:** <name / role> · **Date:** <YYYY-MM-DD> · **Platform:** <name>
· **Participants:** <who else was in the room — ideally a stream engineer>

---

## Level descriptors (reference)

- **L1 Reactive Ops** — manual, ticket-driven, tribal knowledge; time-to-env > 1 week.
- **L2 Standardized DevOps** — CI/CD + IaC + basic monitoring written down; < 1 day.
- **L3 Self-Service** — golden paths, GitOps, observability-as-a-service; < 1 hour.
- **L4 Productized** — IDP catalog/templates/docs, SLOs + on-call, platform-enforced
  security, adoption > 80%; < 10 minutes.
- **L5 Adaptive** — self-healing, self-optimizing, AI-assisted, full cost automation;
  developer satisfaction > 4/5 sustained.

## 1. Rate each dimension (with evidence)

| Dimension | Level (1–5) | Evidence (observable fact — ticket, pipeline, %, survey) |
|-----------|-------------|-----------------------------------------------------------|
| Self-service | <1–5> | <e.g. "new namespace still needs a 2-day ticket"> |
| Delivery (CI/CD) | <1–5> | <e.g. "PR-to-prod automated; rollback is manual"> |
| Observability | <1–5> | <e.g. "each team builds its own dashboards"> |
| Security & policy | <1–5> | <e.g. "Kyverno enforces labels; signing is opt-in"> |
| Reliability (SRE) | <1–5> | <e.g. "platform has no SLOs or on-call of its own"> |
| Cost (FinOps) | <1–5> | <e.g. "no per-team attribution; nobody owns the bill"> |
| Adoption & DX | <1–5> | <e.g. "~55% on the golden path; no DX survey yet"> |
| Organization | <1–5> | <e.g. "mostly self-service, some gatekeeping remains"> |

## 2. Draw the profile

> One block `█` per level. Make the unevenness visible.

```text
Self-service      | <█ per level, e.g. ███      = L3>
Delivery (CI/CD)  | <>
Observability     | <>
Security & policy | <>
Reliability (SRE) | <>
Cost (FinOps)     | <>
Adoption & DX     | <>
Organization      | <>
                    L1  L2  L3  L4  L5
```

## 3. Characterize the platform (one honest sentence)

<e.g. "A Level 3 self-service platform with a Level 1 cost blind spot and no
reliability practice of its own.">

## 4. The one next step

| Field | Your answer |
|-------|-------------|
| Lowest **painful** bar | <dimension> |
| Why this one (evidence of pain + leverage) | <…> |
| What we'll build | <capability; which course phase it draws on> |
| Target | <dimension> L<x> → L<y> by <when> |
| Success signal | <how we'll know it moved — a number or observable change> |
| Prerequisite check | <confirm this doesn't depend on a lower rung we lack> |

---

### Self-check

- [ ] Every rating cites an **observable** fact, not an opinion.
- [ ] Ratings I was unsure about were rounded **down**.
- [ ] I reported a **profile**, not a single averaged number.
- [ ] The next step targets the lowest **painful** bar, not just the lowest number.
- [ ] The next step does not skip a prerequisite rung.
- [ ] At least one person who *consumes* the platform reviewed the grades (or is noted
  as a gap to close next time).

---

## Worked scenario — "Northwind" platform (solo option)

Use this if you have no real platform to assess. Northwind is a fictional 90-engineer
company. Grade it yourself first, then compare with the sample below.

**What's true at Northwind:**

- New services are scaffolded from a shared `cookiecutter` template; CI is a standard
  GitHub Actions workflow every repo inherits. Infrastructure is Terraform in a
  mono-repo applied by the platform team.
- Deploys go through Argo CD (GitOps) once a repo is onboarded, but **onboarding a new
  service to Argo still takes a platform-team PR and ~half a day**.
- Prometheus + Grafana exist; the platform ships a default dashboard, but ~40% of
  teams have drifted to bespoke ones. No DX survey has ever been run.
- Kyverno enforces ownership and cost **labels**; image signing is documented but
  **opt-in**. The platform has no SLOs or on-call rotation of its own — when Argo
  breaks, whoever notices fixes it.
- There is **no cost attribution**; a single finance spreadsheet tracks the total bill,
  which jumped 35% last quarter and nobody could say which team caused it.
- Roughly **65%** of services are on the golden path; the rest predate it.

<details>
<summary>Sample assessment (open after grading it yourself)</summary>

```text
Self-service      | ███          L3   onboarding still needs a platform PR (~half day)
Delivery (CI/CD)  | ████         L4   standard CI + GitOps once onboarded
Observability     | ███          L3   service exists but ~40% drift to bespoke
Security & policy | ███          L3   labels enforced; signing opt-in (not L4)
Reliability (SRE) | ██           L2   no platform SLOs or on-call of its own
Cost (FinOps)     | █            L1   no attribution; surprise 35% jump
Adoption & DX     | ███          L3   ~65% adoption; no DX survey
Organization      | ███          L3   mostly enabling; some onboarding gatekeeping
                    L1  L2  L3  L4  L5
```

- **Characterization:** "A solid Level 3 self-service platform with a Level 1 cost
  blind spot and a Level 2 reliability gap — strong delivery, no view of spend."
- **Lowest painful bar:** **Cost (L1)** — the 35% surprise is causing real, escalated
  pain, and attribution is high-leverage and well-understood.
- **Next step:** deploy OpenCost and publish a per-team weekly showback report
  (Phase 18). Target Cost L1 → L2 this quarter. Signal: every team sees its own weekly
  spend and finance stops escalating. Prerequisite check: cost labels already enforced
  by Kyverno, so attribution has the data it needs — no skipped rung.
- **Runner-up:** Reliability (L2) — giving the platform its own SLOs and on-call
  (Phase 17) — is the natural *next* quarter's step once cost is visible.

</details>
