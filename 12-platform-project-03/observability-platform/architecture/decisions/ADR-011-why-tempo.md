# ADR-011 — Why Tempo over Jaeger

## Status

Accepted
Date: 2026-10-10

## Context

The observability platform needs a distributed tracing backend to store and query
traces emitted (via OpenTelemetry) by instrumented services. The two common
open-source choices are **Grafana Tempo** and **Jaeger**. Both ingest OTLP and serve
traces; the decision is about operational cost, storage model, and integration with
the rest of the stack (Prometheus, Loki, Grafana).

Constraints: we already run Grafana, Loki, and Prometheus; we want cheap, scalable
storage; and we want traces correlated with logs and metrics.

## Decision

We will use **Grafana Tempo** as the tracing backend.

## Consequences

- **Easier:** Tempo stores traces in cheap **object storage** (GCS/S3) and indexes
  only by trace ID by default, which keeps cost low at scale; it integrates natively
  with Grafana and with Loki/Prometheus for **trace-to-log** and **exemplar**
  correlation.
- **Easier:** one vendor's stack (Grafana LGTM) means one set of operational
  patterns, dashboards, and auth.
- **Harder / trade-offs:** Tempo's "no rich index" model means powerful
  attribute-based search relies on TraceQL + metrics-generator rather than Jaeger's
  historical tag index; Jaeger's UI is more trace-search-centric out of the box.

## Alternatives considered

- **Jaeger** — mature, CNCF-graduated, great trace-search UI; a completely valid
  choice. We prefer Tempo for its object-storage cost model and tight integration
  with the Grafana stack we already operate.
- **A SaaS tracing vendor** — less to operate, but cost and data-egress concerns, and
  outside the "build it on open source" spirit of the course.

## References

- [Grafana Tempo documentation](https://grafana.com/docs/tempo/latest/)
- [Jaeger](https://www.jaegertracing.io/)
- [Phase 9 · Distributed Tracing with Tempo](../../../../11-observability-engineering/05-distributed-tracing-with-tempo/)
