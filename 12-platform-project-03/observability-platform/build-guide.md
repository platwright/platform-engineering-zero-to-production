# Build Guide — Observability Platform

> The staged walkthrough. **Pass 1** stands up the full LGTM + OTel stack on a free
> local `kind` cluster, instruments a sample app, shows all three pillars in Grafana,
> and makes an SLO alert fire. **Pass 2** delivers it via GitOps and hardens it. Pass
> 1 takes ~1.5–2 hours (plus install time).

**Type:** Build project
**Deliverable:** A running metrics/logs/traces stack with a sample app's telemetry
visible in Grafana, a Platform Overview Dashboard from code, and an SLO burn-rate
alert you triggered.

## Prerequisites

- Docker (give it **≥ 8 GB RAM**), `kubectl`, `kind`, `helm`.
- You're in this project directory:
  `12-platform-project-03/observability-platform/`.

---

## Pass 1 — Build it now (local, free)

### Stage 0 — Stand up the stack

```bash
./scripts/bootstrap.sh
```

This creates a kind cluster and Helm-installs Prometheus, Grafana, Alertmanager,
Loki, Tempo, and the OTel Collector (both a **gateway Deployment** and an **agent
DaemonSet** — see [ADR-017](./architecture/decisions/ADR-017-collector-topology.md)).
Give it a few minutes; the images are large.

```bash
kubectl -n observability get pods       # wait until everything is Running/Ready
```

### Stage 1 — Open Grafana and see the backends

```bash
kubectl -n observability port-forward svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  (user: admin, password: admin — LOCAL ONLY)
```

In **Explore**, switch the datasource between **Prometheus**, **Loki**, and
**Tempo**. All three are wired up (datasources are provisioned from
[config-repo/platform/grafana/datasources.yaml](./config-repo/platform/grafana/datasources.yaml)).
You have metrics, logs, and traces in one place — the whole point.

### Stage 2 — Instrument and deploy the sample app

Deploy an OTLP-emitting sample app so there's real telemetry to look at. The
[OpenTelemetry demo](https://opentelemetry.io/docs/demo/) is the fastest way, or use
any app with the OTel SDK pointing at the gateway:

```text
OTEL_EXPORTER_OTLP_ENDPOINT = http://otel-agent.observability.svc:4317
```

The app sends OTLP to the **agent** (node-local), which forwards to the **gateway**,
which batches, **tail-samples** traces (keeps errors + slow traces), and fans out to
Prometheus / Loki / Tempo.

```bash
# Generate some load so there's data to see
kubectl -n observability run load --image=busybox --restart=Never -- \
  sh -c 'for i in $(seq 1 500); do wget -qO- http://sample-app.observability.svc/ >/dev/null; done'
```

### Stage 3 — Follow one request across all three pillars

This is the exercise that makes observability click:

1. In **Explore → Tempo**, find a recent trace (search by service). Open it and read
   the spans.
2. From a span, use **trace-to-logs** to jump into **Loki** and see that request's
   logs.
3. In **Explore → Prometheus**, chart the request rate and p99 latency; an
   **exemplar** dot links back to a **Tempo** trace.

One request, three signals, correlated — metrics tell you *something's wrong*, traces
tell you *where*, logs tell you *why*.

### Stage 4 — Import the Platform Overview Dashboard (as code)

The dashboard lives in Git, not a manual export
([dashboards/platform-overview.json](./dashboards/platform-overview.json)):

```bash
# Quickest for the lab: Grafana → Dashboards → New → Import → upload the JSON.
# Production path: provision it from a ConfigMap (see grafana/dashboard-provider.yaml).
```

It shows CPU/memory by namespace, request + error rate per service, p50/p95/p99
latency, the ArgoCD sync-error SLI, and recent error logs.

### Stage 5 — Define an SLO and make a burn-rate alert fire

Apply the simple hand-written rule first so you can *see* an alert fire without the
full Sloth pipeline:

```bash
kubectl apply -f config-repo/platform/prometheus/sample-alert-rule.yaml
```

Now break the SLI — drive the sample app's error ratio above 5% (for example, point
load at an endpoint that 500s, or scale the app to zero so requests fail):

```bash
kubectl -n observability scale deployment/sample-app --replicas=0   # force failures
# ... wait ~2–3 minutes ...
```

Watch the alert go from inactive → pending → firing:

```bash
# Prometheus UI (port-forward) → Alerts, or:
kubectl -n observability port-forward svc/kube-prometheus-stack-prometheus 9090:9090
# http://localhost:9090/alerts  → SampleServiceHighErrorRate
```

Then restore the app and watch it resolve:

```bash
kubectl -n observability scale deployment/sample-app --replicas=2
```

> The **production** approach is a Sloth SLO
> ([config-repo/slos/argocd-slo.yaml](./config-repo/slos/argocd-slo.yaml)) that
> generates multi-window burn-rate alerts — you page on fast burns, ticket on slow
> ones. Generate the rules with `sloth generate -i config-repo/slos/argocd-slo.yaml`.

### Stage 6 — Clean up

```bash
./scripts/cleanup.sh             # deletes the kind cluster and everything in it
```

---

## Pass 2 — Harden to production (as later pieces allow)

1. **Deliver the whole stack via GitOps.** Put `config-repo/` under ArgoCD (from
   Project 2) so the observability platform is itself reproducible and auditable.
   → [Project 2 · GitOps](../../09-platform-project-02/)
2. **Long-term storage in GCS.** Point Loki and Tempo at object storage; add
   Mimir/remote-write for 1-year metrics.
   → cost is a [Phase 14 · FinOps](../../18-finops-and-cost-engineering/) concern
3. **Alertmanager → Slack, runbook-linked.** Wire
   [alertmanager-routing.yaml](./config-repo/platform/alertmanager/alertmanager-routing.yaml)
   with a webhook from a secret manager (ESO, never in Git), and link every alert to a
   [runbook](./docs/runbooks/).
   → [Phase 10 · Security](../../13-security-and-policy-engineering/) for the secret
4. **SLOs for ArgoCD, Prometheus, and the gateway** via Sloth.

As you finish each, update the
[portfolio-ready checklist](./README.md#portfolio-ready-checklist).

---

## Reflection

- You found a problem three ways: a metric told you *something* was wrong, a trace
  told you *where*, a log told you *why*. Which would you reach for first, and why
  does having all three matter?
- The gateway tail-samples traces (keeps errors/slow, drops most). What do you gain,
  and what do you lose, by not keeping 100%?
- The alert you fired was a simple threshold. Why is a **burn-rate** alert (Sloth)
  better for an SLO than "error rate > 5% for 2m"?
