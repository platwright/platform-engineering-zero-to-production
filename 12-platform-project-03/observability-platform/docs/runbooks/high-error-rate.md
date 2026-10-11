# Runbook — SampleServiceHighErrorRate (burn-rate / error-rate alert)

> **Linked from:** the `SampleServiceHighErrorRate` alert (and the pattern for any
> service error-rate / SLO burn-rate alert).
> **Severity:** page.

## What it means

The service's 5xx error ratio has exceeded the threshold (sample rule: > 5% over
5 minutes). For an SLO burn-rate alert, it means the error budget is being spent too
fast. Users are likely seeing failures **now**.

## Triage (first 5 minutes)

1. **Confirm scope** in Grafana (Platform Overview → error rate per service):

   ```promql
   sum by (service) (rate(http_requests_total{status=~"5.."}[5m]))
     / sum by (service) (rate(http_requests_total[5m]))
   ```

2. **Is it one service or many?** Many services failing together points at a shared
   dependency (database, the platform itself), not one app.

3. **Correlate with a trace.** In Grafana Explore → Tempo, open a failing trace for
   the service and read the error span — it usually names the failing downstream.

4. **Read the logs.** From the trace, jump to Loki (`trace_id` link) and read the
   error messages.

## Common causes and actions

- **A bad deploy.** Check whether the error rate rose right after a rollout. If so,
  roll back (GitOps: revert the commit — see Project 2's
  [rollback runbook](../../../../09-platform-project-02/gitops-platform/docs/runbooks/rollback-a-change.md)).
- **A failing dependency** (database, cache, downstream service). The trace will show
  which. Mitigate the dependency; consider shedding load or enabling a fallback.
- **Resource exhaustion** (OOMKilled / CPU throttling). Check pod status and the
  memory/CPU panels; raise limits or scale out.
- **Upstream load spike.** Check the request-rate panel; scale the service (HPA) if
  it's simply overwhelmed.

## Verify recovery

- Error ratio returns below the threshold and the alert resolves.
- Traces show successful spans again; error logs stop.
- If this was an SLO burn-rate alert, confirm the budget stops burning.

## After the incident

- Write (or update) a blameless postmortem.
- If the alert was noisy or fired late, tune the SLO/burn-rate windows (Sloth).
- Ensure the fix is captured in code (GitOps), not a manual cluster change.
