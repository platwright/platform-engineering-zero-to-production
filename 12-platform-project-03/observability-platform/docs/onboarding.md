# Onboarding a service onto the observability platform

> This runbook makes a team's service **observable by default**: emitting metrics,
> logs, and traces to the platform with no per-team backend to run. In Pass 1 it's a
> short manual procedure; the platform-engineering goal is to bake this into the
> golden-path template so every new service is observable from its first commit.

## Outcome

A service that:

- emits OTLP telemetry to the platform collector (no Prometheus/Tempo to self-host),
- appears in Grafana (metrics, logs, traces), and
- has at least one SLO defined.

## Procedure

1. **Instrument the app with the OpenTelemetry SDK.** Use auto-instrumentation where
   available (Java/Python/Node), or the SDK for custom spans/metrics. Point it at the
   platform's node-local agent:

   ```text
   OTEL_EXPORTER_OTLP_ENDPOINT = http://otel-agent.observability.svc:4317
   OTEL_SERVICE_NAME           = <your-service-name>
   OTEL_RESOURCE_ATTRIBUTES    = team=<team>,environment=<env>
   ```

2. **Emit structured logs** that include the `trace_id`, so Grafana can link a log
   line to its trace (the Loki datasource is configured to do this).

3. **Confirm telemetry arrives.** In Grafana → Explore, query the service in
   Prometheus (request rate), Loki (logs), and Tempo (a trace). If nothing shows,
   see [service-not-reporting-telemetry.md](./runbooks/service-not-reporting-telemetry.md).

4. **Add a dashboard panel (optional).** Add the service to the Platform Overview
   Dashboard or create a service dashboard as code under
   [../dashboards/](../dashboards/).

5. **Define an SLO.** Write a short Sloth spec (good/total event queries) under
   [../config-repo/slos/](../config-repo/slos/), modeled on
   [argocd-slo.yaml](../config-repo/slos/argocd-slo.yaml). Generate the burn-rate
   rules and load them into Prometheus.

6. **Write a runbook** for each alert the SLO produces, and link it in the alert's
   `runbook_url` annotation. An alert with no runbook is noise.

## Definition of done

- [ ] Service emits OTLP to the platform collector.
- [ ] Metrics, logs, and traces for the service are visible in Grafana.
- [ ] Logs carry `trace_id` for trace-to-log correlation.
- [ ] At least one SLO defined with a burn-rate alert.
- [ ] Every alert links to a runbook.

## Make it self-service (later)

Doing this per service by hand is Pass 1. The platform move is to pre-wire the OTel
SDK, a default dashboard, and a starter SLO into the golden-path service template so a
new service is observable from day one — the subject of
[Phase 12 · Developer Experience & IDP](../../../15-developer-experience-and-idp/).
