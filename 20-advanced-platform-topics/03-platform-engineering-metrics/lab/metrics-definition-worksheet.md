<!-- markdownlint-disable MD033 -->
# Platform Metrics Definition

> Copy and fill in. Keep the set small (6–8 metrics) and balanced across the three
> lenses. Every metric needs a source, a cadence, a target, a **paired guardrail**,
> and a baseline. Derive metrics from goals (GQM), not from whatever is easy to
> collect.

**Author:** <name> · **Date:** <YYYY-MM-DD> · **Platform:** <name>

---

## 1. Goal → questions (GQM)

- **Goal:** <one sentence — what the platform is for>
- **Questions the numbers must answer:**
  - <e.g. "How fast can a new team reach production, and do they trust it?">
  - <e.g. "Are teams choosing the golden path, or routing around it?">
  - <e.g. "Is the platform itself reliable?">

## 2. Metric set (6–8 rows, all three lenses)

| Metric | Lens | What it is | Source | Cadence | Target | Paired guardrail | Baseline (today) |
|--------|------|-----------|--------|---------|--------|------------------|------------------|
| <golden-path adoption> | Adoption | <% services from golden path> | <catalog/Git> | <weekly> | <> 80%> | <DX survey> | <?> |
| <time-to-first-deploy> | Experience (E) | <new team repo → prod> | <pipeline> | <monthly> | << 1 day> | <change-fail rate> | <?> |
| <deployment frequency> | Delivery (DORA) | <platform ships / team ships> | <GitOps/CD> | <weekly> | <> | <change-fail rate> | <?> |
| <change failure rate> | Delivery (DORA) | <% changes causing incident> | <incidents+CD> | <monthly> | << 15%> | <deploy freq> | <?> |
| <developer NPS> | Satisfaction (S) | <"recommend the platform?"> | <quarterly survey> | <quarterly> | <> +20> | <adoption depth> | <?> |
| <% services with SLOs> | Adoption | <reliability maturity> | <catalog> | <monthly> | <> | <> | <?> |
| <> | <> | <> | <> | <> | <> | <> | <?> |
| <> | <> | <> | <> | <> | <> | <> | <?> |

## 3. Which DORA direction?

<For each DORA metric above, say whether it measures the PLATFORM'S OWN delivery
(direction 1) or the EFFECT ON TEAMS you serve (direction 2). Both are valid; be
explicit so nobody conflates them.>

## 4. Dashboard layout (the four panels)

```text
┌──────────────────────────────┬──────────────────────────────┐
│ ① Platform SLO status         │ ② Active incidents            │
│   <which SLOs? source?>        │   <source? severity/age?>     │
│   REAL-TIME                    │   REAL-TIME                   │
├──────────────────────────────┼──────────────────────────────┤
│ ③ Change activity (DORA)       │ ④ DX trend + adoption         │
│   <deploys, lead time, CFR>    │   <NPS, adoption %, TTFD>     │
│   TREND                        │   TREND                      │
└──────────────────────────────┴──────────────────────────────┘
```

Import option: [`platform-health-dashboard.json`](./platform-health-dashboard.json)
(adapt its placeholder queries to your real metrics).

## 5. Review ritual

| Field | Your answer |
|-------|-------------|
| Where the dashboard is reviewed | <weekly platform review / monthly ops review> |
| A decision it will change | <e.g. "if adoption stalls, re-prioritize the roadmap"> |
| Who owns acting on it | <role> |

---

### Self-check

- [ ] Metrics span **all three** lenses (delivery, experience, adoption).
- [ ] Every metric has a source, cadence, target, **paired guardrail**, and baseline.
- [ ] No metric is an **individual**-productivity count.
- [ ] No target can be hit by **mandating** adoption at the cost of satisfaction.
- [ ] Each DORA metric states its **direction** (own delivery vs effect on teams).
- [ ] The dashboard is tied to a **review** where a number changes a decision.
- [ ] The set is small enough (6–8) that the team will actually act on it.
