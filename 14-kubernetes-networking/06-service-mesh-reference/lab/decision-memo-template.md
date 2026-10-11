<!-- markdownlint-disable MD033 -->
# Service Mesh Decision Memo

> Copy and fill in. One page. The goal is a defensible recommendation, not a tool
> tour. Map every requirement to the lightest tool that meets it.

**Author:** <name> · **Date:** <YYYY-MM-DD> · **Scenario:** <A / B / C / real system>

---

## Context

<The system: how many services, how many teams, what it does, current network stack
(CNI, ingress, observability), and the team's operational maturity.>

## Requirements

| # | Requirement | Hard or nice-to-have? |
|---|-------------|-----------------------|
| 1 | <e.g. mTLS between all services> | hard |
| 2 | <e.g. canary deploys> | nice |
| 3 | <e.g. circuit breaking / fault injection> | <?> |
| 4 | <e.g. uniform L7 telemetry without app changes> | <?> |

## Options considered (map each requirement to the lightest tool)

| Requirement | Cilium | Gateway API | OpenTelemetry | Service mesh (Istio) |
|-------------|:------:|:-----------:|:-------------:|:--------------------:|
| mTLS between services | ✅? | — | — | ✅ |
| Ingress + weighted canary | — | ✅? | — | ✅ |
| Per-service metrics/traces | — | — | ✅? | ✅ |
| Rich resilience (circuit break, fault inj., mirroring) | partial | — | — | ✅ |
| Uniform L7 telemetry, no app changes, large fleet | partial | — | depends | ✅ |

_(Mark ✅ where a tool fully meets the requirement; note gaps.)_

## Recommendation

<One of:>

- **No mesh.** Cover the requirements with <Cilium + Gateway API + OTel>, because <…>.
- **Adopt a mesh.** Specifically <Istio, ambient mode>, rolled out <incrementally,
  namespace X first>, because these residual requirements are met *only* by a mesh:
  <…>.

## Risks & mitigations

- <risk> → <mitigation>
- <risk> → <mitigation>

## What would change this decision

<The specific future requirement(s) that would flip the recommendation — e.g.
"if we add 50 services that can't be instrumented and need org-wide L7 telemetry."><br>

---

### Self-check

- [ ] Every requirement is mapped to the lightest tool that satisfies it.
- [ ] The recommendation names residual needs only a mesh meets (if recommending one).
- [ ] If a mesh: ambient vs sidecar is specified, and rollout is incremental.
- [ ] A skeptic couldn't trivially meet the requirements with a cheaper option.
