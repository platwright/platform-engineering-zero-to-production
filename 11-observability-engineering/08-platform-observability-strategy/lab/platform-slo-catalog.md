<!-- markdownlint-disable MD033 -->
# Platform SLO catalog

A *small* set of meaningful SLOs for the platform's own services. Each needs an owner,
a page target, and a runbook — an SLO nobody watches is theatre. Two example rows are
started for you; complete them and add your own. Replace every `<placeholder>`.

| Service | SLI (what is measured) | SLO target | Error-budget consequence | Pages | Runbook |
|---------|------------------------|-----------|--------------------------|-------|---------|
| Argo CD | Sync success ratio: `1 - (errored syncs / total syncs)` | 99.9% | Freeze risky platform changes; fix delivery | platform on-call | `runbooks.example.com/argocd` |
| API server | Non-5xx request ratio and p99 latency | 99.95% | Halt cluster-wide rollouts; investigate control plane | platform on-call | `runbooks.example.com/apiserver` |
| Grafana | `<SLI>` | `<target>` | `<consequence>` | `<who>` | `<runbook>` |
| External Secrets Operator | `<SLI>` | `<target>` | `<consequence>` | `<who>` | `<runbook>` |
| OTel Collector | `<SLI>` | `<target>` | `<consequence>` | `<who>` | `<runbook>` |
| `<your service>` | `<SLI>` | `<target>` | `<consequence>` | `<who>` | `<runbook>` |

## Notes

- Keep SLIs **user-centred and event-based** (good events ÷ valid events), not proxies
  like CPU.
- Set each SLO **stricter** than any external SLA so you react before a breach.
- Alert on these with **multi-window, multi-burn-rate** rules (Module 11.7), not raw
  thresholds.
