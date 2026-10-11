# Runbook — checkout-service unavailable

> Linked from the `CheckoutServiceDown` alert via its `runbook_url` annotation. Written
> for a stressed on-call engineer: confirm, diagnose, mitigate, escalate.

## Symptom

The `CheckoutServiceDown` alert is firing: the service is returning 5xx errors or
failing its health check, and checkouts are failing for users.

## Confirm

```bash
# Is it actually down? Check readiness and recent error rate.
kubectl -n payments get pods -l app.kubernetes.io/name=checkout-service
platform logs --app checkout-service --env prod --since 15m
```

- Check the service dashboard (golden signals) for error-rate and latency spikes.
- Confirm the alert is not a false positive from a probe misconfiguration.

## Likely causes

- **Bad deploy** — a recent rollout introduced a regression.
- **Dependency down** — the payment gateway or orders database is unavailable.
- **Resource exhaustion** — pods OOMKilled or CPU-throttled under load.

## Mitigation

1. **If a recent deploy is the cause, roll back** to the previous known-good version:

   ```bash
   platform deploy --app checkout-service --version <previous-good-sha> --env prod
   ```

2. **If a dependency is down**, check `payment-gateway` and `orders-database` status
   and follow their runbooks; put checkout into a graceful degraded mode if available.

3. **If resources are exhausted**, check limits and recent traffic; scale out if the
   spike is legitimate.

## Escalate

- If not mitigated within 15 minutes, page the secondary on-call for `team-payments`.
- For a customer-facing outage, open an incident and notify the incident channel.

## After the incident

- Capture the timeline and write (or update) an ADR if the fix changes the
  architecture.
- File follow-up work to remove the cause; update this runbook with anything you wished
  it had said.
