# ADR-015 — Why OpenTelemetry as the collection standard

## Status

Accepted
Date: 2026-10-10

## Context

Applications on the platform need to emit metrics, logs, and traces. Historically
each backend had its own agent and SDK (Prometheus client libs, a tracing-vendor SDK,
a logging agent), which couples application code to specific backends and makes
swapping or adding a backend a cross-codebase change. We want a single, vendor-neutral
instrumentation and collection standard.

Constraints: many languages across many teams; a desire to avoid re-instrumenting
apps when backends change; and a collection tier we can evolve independently of
application code.

## Decision

We will standardize on **OpenTelemetry (OTel)** — the OTel SDKs for instrumentation
and the **OTel Collector** for collection, processing, and export (OTLP).

## Consequences

- **Easier:** applications instrument **once** against a vendor-neutral API and send
  OTLP to the collector; the platform decides where signals go (Prometheus, Loki,
  Tempo, or a different backend tomorrow) with **no app changes**.
- **Easier:** the collector centralizes processing — batching, attribute scrubbing,
  tail sampling — off the critical path of the app.
- **Easier:** OTel is a CNCF project and the de-facto industry standard, so SDKs,
  auto-instrumentation, and community support are broad.
- **Harder / trade-offs:** OTel is still maturing in places (logs are newer than
  traces/metrics); running a collector tier is another component to operate; some
  advanced backend features sit behind backend-specific exporters.

## Alternatives considered

- **Backend-native agents/SDKs** (Prometheus client + a tracing-vendor SDK + Promtail)
  — fewer moving parts initially, but couples apps to backends and makes change
  expensive. Rejected as the default.
- **A single-vendor observability SaaS SDK** — convenient but lock-in; contrary to the
  course's open, portable approach.

## References

- [OpenTelemetry documentation](https://opentelemetry.io/docs/)
- [OTel Collector](https://opentelemetry.io/docs/collector/)
- [Phase 9 · OpenTelemetry](../../../../11-observability-engineering/02-opentelemetry/)
