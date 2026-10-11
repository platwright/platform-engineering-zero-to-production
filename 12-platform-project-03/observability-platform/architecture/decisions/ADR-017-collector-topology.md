# ADR-017 — Why a DaemonSet + gateway collector topology

## Status

Accepted
Date: 2026-10-10

## Context

The OpenTelemetry Collector can be deployed in several topologies: as a per-node
**agent** (DaemonSet), as a centralized **gateway** (Deployment), or both. The choice
affects where host metrics and logs are collected, where trace processing (batching,
tail sampling) happens, and how the system scales.

Constraints: we need per-node signals (host metrics, pod logs) that only a node-local
agent can gather; we need **tail-based sampling** of traces (which requires seeing a
whole trace in one place); and we want the collection tier to scale independently of
both the apps and the backends.

## Decision

We will run the collector in **both** roles: a **DaemonSet** agent on every node and a
horizontally-scalable **gateway** Deployment.

## Consequences

- **Easier:** the DaemonSet sits next to workloads to collect node/host metrics and
  tail pod logs locally — cheap and with no central bottleneck for high-volume,
  node-local data.
- **Easier:** the gateway centralizes trace aggregation so **tail-based sampling**
  (keep error/slow traces, drop most of the rest) actually works — a single agent
  can't make that decision because it only sees part of a trace. The gateway also
  does batching and attribute scrubbing off the app's critical path, and scales out
  under load.
- **Harder / trade-offs:** two collector deployments to configure and operate instead
  of one; traffic makes an extra hop (agent → gateway) for traces. For a tiny cluster
  this is more than strictly necessary — but it's the pattern that scales, which is
  what a platform must teach and run.

## Alternatives considered

- **Agent-only (DaemonSet)** — simplest, but can't do cluster-wide tail sampling and
  pushes all export/processing onto each node. Fine for small setups; doesn't scale
  the trace pipeline.
- **Gateway-only (Deployment)** — centralizes processing but can't collect node-local
  host metrics/logs well, and makes the gateway a single choke point for everything.
- **Sidecar per pod** — fine-grained but heavy (a collector per workload) and
  operationally noisy.

## References

- [OTel Collector deployment patterns](https://opentelemetry.io/docs/collector/deployment/)
- [Tail-based sampling](https://opentelemetry.io/docs/concepts/sampling/#tail-sampling)
- [Phase 9 · OpenTelemetry](../../../../11-observability-engineering/02-opentelemetry/)
