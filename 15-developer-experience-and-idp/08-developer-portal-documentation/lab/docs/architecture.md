# Architecture

`checkout-service` creates and completes checkouts. It exposes the `checkout-api`,
persists state in the orders database, and calls the payment gateway to authorize
payments.

## Context diagram

```text
      client ──► checkout-service ──► payment-gateway ──► (external processor)
                      │
                      ▼
                orders-database (PostgreSQL)
```

## Dependencies

- **payment-gateway** (component) — authorizes and captures payments.
- **orders-database** (resource) — stores orders and checkout state.

These relationships are declared in `catalog-info.yaml` (`dependsOn`) and rendered in
the portal's dependency graph.

## Request flow

1. A client calls `POST /checkouts` to create a checkout.
2. The service writes a `pending` order to the orders database.
3. On `POST /checkouts/{id}/complete`, it calls the payment gateway.
4. On success it marks the order `completed`; on failure, `failed`.

## Observability

The service emits OpenTelemetry traces and metrics (golden signals). Its dashboard and
alerts are provisioned by the golden path; alerts link to the
[runbooks](runbooks/service-unavailable.md).
