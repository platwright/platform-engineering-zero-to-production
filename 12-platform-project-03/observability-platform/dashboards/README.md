# Dashboards (as code)

Grafana dashboards live here as versioned JSON, not hand-exported from the UI. The
platform provisions them from a ConfigMap (see
[../config-repo/platform/grafana/dashboard-provider.yaml](../config-repo/platform/grafana/dashboard-provider.yaml)).

| File | What it shows |
|------|---------------|
| [`platform-overview.json`](./platform-overview.json) | CPU/memory by namespace, request + error rate per service, p50/p95/p99 latency, the ArgoCD sync-error SLI, and recent error logs. |

## Why dashboards as code?

- **Reviewable.** A dashboard change is a diff in a pull request, not a silent UI edit.
- **Reproducible.** Rebuild Grafana and the dashboards come back exactly.
- **Portable.** The same dashboard deploys to dev, staging, and prod.

## Editing

Edit in the Grafana UI to iterate quickly, then export the JSON and commit it — or
edit the JSON directly. For larger dashboard libraries, generate JSON from
**Jsonnet** (Grafonnet) so panels are composable; the outline's Platform Overview is
a good first candidate to port to Jsonnet as a stretch goal.

> Keep the `uid` stable across edits so links and provisioning keep working.
