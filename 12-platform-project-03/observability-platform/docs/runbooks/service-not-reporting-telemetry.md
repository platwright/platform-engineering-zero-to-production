# Runbook — A service isn't reporting telemetry

> **When to use:** a team onboarded a service but its metrics, logs, or traces don't
> appear in Grafana.

## Quick checks (in order)

1. **Is the app exporting to the right endpoint?** It should send OTLP to the
   node-local agent:

   ```text
   OTEL_EXPORTER_OTLP_ENDPOINT = http://otel-agent.observability.svc:4317
   ```

   A wrong host/port (or pointing straight at a backend) is the most common cause.

2. **Are the collectors healthy?**

   ```bash
   kubectl -n observability get pods -l app.kubernetes.io/name=opentelemetry-collector
   kubectl -n observability logs deploy/otel-gateway --tail=100
   kubectl -n observability logs ds/otel-agent --tail=100
   ```

   Look for receiver/exporter errors (TLS, unreachable backend, auth).

3. **Which pillar is missing?**
   - **Metrics missing** — check the gateway's Prometheus exporter and that
     Prometheus is scraping it; check for dropped metrics from cardinality limits.
   - **Logs missing** — check the agent's `filelog` receiver and that the app writes
     to stdout/stderr (so `/var/log/pods` captures it).
   - **Traces missing** — check the gateway's `tail_sampling`: if the app only
     produced successful, fast requests, the probabilistic policy may have dropped
     them. Generate an error/slow request and look again.

4. **Is it a sampling illusion?** Tail sampling keeps errors + slow traces and drops
   most of the rest. "I don't see my trace" is often "it was sampled out" — force an
   error or slow path to confirm the pipeline works.

5. **Namespace/label mismatch.** Confirm `OTEL_RESOURCE_ATTRIBUTES`
   (`team`, `environment`) and `OTEL_SERVICE_NAME` are set, or dashboards filtered by
   those labels will show nothing.

## Escalation

If the collectors themselves are crashing or backends are unreachable cluster-wide,
treat it as a platform incident: the observability stack is tier-1 infrastructure. Its
own health is monitored per
[Module 11.8 · Platform Observability Strategy](../../../../11-observability-engineering/08-platform-observability-strategy/).
