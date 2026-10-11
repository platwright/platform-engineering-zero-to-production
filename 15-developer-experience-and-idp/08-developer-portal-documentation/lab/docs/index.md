# checkout-service

Handles payment and order checkout for the order-management system. Owned by
`team-payments`.

This documentation lives with the code (docs-as-code) and is rendered in the developer
portal by TechDocs. Change it in the same pull request as the code it describes.

## Run locally

```bash
go run .
# serves on :8080
curl localhost:8080/healthz
```

## Quick facts

- **Owner:** `team-payments` (`#team-payments` on chat)
- **System:** order-management
- **Lifecycle:** production
- **API:** see the `checkout-api` entity in the catalog

## Where to go next

- [Architecture](architecture.md) — how the service works and what it depends on.
- [Runbook: service unavailable](runbooks/service-unavailable.md) — what to do when it
  pages you.
- [ADR 0001](adr/0001-record-architecture-decisions.md) — why we keep decision records.
