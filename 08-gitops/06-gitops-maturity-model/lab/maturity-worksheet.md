<!-- markdownlint-disable MD033 -->

# GitOps maturity worksheet

Fill in each `<placeholder>`. Score every dimension 0–4 and record the evidence you
could actually show (a repo path, a dashboard, a metric). If you can't show it, it
isn't that level. See the level and dimension descriptions in
[the module](../README.md).

## Target under assessment

- Platform / team: <name>
- Date: <yyyy-mm-dd>
- Assessor: <you>
- Scenario: <real platform / Acme>

## Dimension scores

| Dimension | Score (0-4) | Evidence (what you can show) |
|-----------|-------------|------------------------------|
| Source of truth (all state in Git?) | <score> | <evidence> |
| Sync automation (manual to hands-off) | <score> | <evidence> |
| Drift & self-healing (detected? alerted?) | <score> | <evidence> |
| Secrets (plaintext to managed store) | <score> | <evidence> |
| Promotion (manual to PR-driven with gates) | <score> | <evidence> |
| Scope (apps only to all cluster config) | <score> | <evidence> |
| Progressive delivery (big-bang to canary) | <score> | <evidence> |
| Multi-cluster (one to fleet control plane) | <score> | <evidence> |
| Policy & compliance (review to enforced at sync) | <score> | <evidence> |
| Observability of sync (visible? alerted?) | <score> | <evidence> |

## Overall rating

- Overall level (the weakest *painful* dimension, not an average): <level>
- Why this level — which dimension limits you and what it risks: <1-2 sentences>

## Prioritized next step

- The single next step: <what you will do>
- Why it's first — justify against the dimensions and risk: <2-3 sentences>
- How you'll know it worked — the evidence or metric: <measure>

## Optional: roadmap to target

- Target level and why it's right for your stakes: <level + rationale>
- Rung 1 (next): <step>
- Rung 2: <step>
- Rung 3: <step>
