# Lab — A Platform Overview Dashboard as code

> You will deploy the metrics stack on kind, then ship a **Platform Overview
> Dashboard** — authored as Grafonnet and provided as ready-to-import JSON — into
> Grafana the GitOps way (a sidecar-watched ConfigMap). You will watch it populate
> with namespace CPU, RED, latency, SLO burn, and active alerts, and template it by
> service. Local and free.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** A versioned Platform Overview Dashboard (Jsonnet source + JSON) loaded
into Grafana from Git-as-ConfigMap and populated with live data.

## Objectives

- Deliver a dashboard **as code** and deploy it via a sidecar ConfigMap.
- Build a top-down board: summary on top, breakdowns below.
- Template the board with variables so it serves any service.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), and
  [Helm](https://helm.sh/).
- [Module 11.3](../../03-metrics-with-prometheus/) (you reuse its sample app) and
  [Module 11.6](../README.md) theory.
- Starter files in this folder: [`platform-overview.json`](./platform-overview.json)
  (import-ready) and [`platform-overview.jsonnet`](./platform-overview.jsonnet)
  (the source of truth).

## Steps

1. **Create a cluster and install the stack.**

   ```bash
   kind create cluster --name pe-grafana
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
     --version 65.5.1 --namespace monitoring --create-namespace
   kubectl -n monitoring rollout status deploy/kube-prom-stack-kube-prometheus-operator
   ```

2. **Give the board some data to show.** Reuse the Module 11.3 sample app and
   ServiceMonitor, then drive traffic:

   ```bash
   kubectl apply -n monitoring -f ../../03-metrics-with-prometheus/lab/sample-app.yaml
   kubectl apply -n monitoring -f ../../03-metrics-with-prometheus/lab/servicemonitor.yaml
   kubectl -n monitoring run load --image=busybox:1.36 --restart=Never -- \
     /bin/sh -c 'while true; do \
       wget -q -O- http://prometheus-example-app:8080/ >/dev/null; \
       wget -q -O- http://prometheus-example-app:8080/err >/dev/null; \
       sleep 0.2; done'
   ```

3. **Ship the dashboard as code.** The kube-prometheus-stack Grafana runs a sidecar
   that imports any ConfigMap labelled `grafana_dashboard=1`. Create one from the JSON
   and label it — a merged file becomes a live dashboard, GitOps-style:

   ```bash
   kubectl -n monitoring create configmap platform-overview-dashboard \
     --from-file=platform-overview.json
   kubectl -n monitoring label configmap platform-overview-dashboard grafana_dashboard=1
   ```

4. **Open Grafana and find the board.** Port-forward Grafana and log in:

   ```bash
   kubectl -n monitoring port-forward svc/kube-prom-stack-grafana 3000:80
   # user: admin   password: prom-operator
   ```

   Browse **Dashboards → Platform Overview**. Within a minute the sidecar imports it.

5. **Read it top-down.** Confirm the layout answers questions in order: namespace CPU
   and memory (where is the load?), request and error rate per service (what is
   wrong?), p50/p95/p99 latency (how bad?), SLO burn rate (are we spending budget too
   fast?), and tables for rollout activity and firing alerts (what changed / what is
   on fire?).

6. **Template it.** Use the **service** dropdown at the top of the board. Every
   per-service panel re-queries for the selected `job` — one dashboard, any service.
   That variable is why you do not build a board per team.

7. **See the source of truth.** Open
   [`platform-overview.jsonnet`](./platform-overview.jsonnet). This Grafonnet file
   *generates* the JSON you imported. In a real repo you would render it in CI
   (`jsonnet -J vendor platform-overview.jsonnet > platform-overview.json`), review the
   diff, and let the sidecar apply it — dashboards reviewed and versioned like any code.

## Expected result

A **Platform Overview** dashboard appears in Grafana (loaded from the ConfigMap, not
hand-imported) and populates: namespace CPU/memory time series, a ~50% error rate and
request rate for `prometheus-example-app`, p50/p95/p99 latency, a non-zero SLO burn
rate, and a firing-alerts table. The **service** variable re-scopes the per-service
panels.

## Cleanup

> Always tear down — this stack is resource-hungry. Never skip this.

```bash
kubectl -n monitoring delete pod load --ignore-not-found
kubectl -n monitoring delete configmap platform-overview-dashboard --ignore-not-found
helm uninstall kube-prom-stack --namespace monitoring --ignore-not-found
kind delete cluster --name pe-grafana
```

## Reflection

- You deployed a dashboard by creating a labelled ConfigMap, not by clicking "import."
  Why is that a better fit for a platform that must reproduce dashboards across many
  clusters?
- Two panels on this board (rollout activity, active incidents) are stand-ins. Which
  real data sources would you wire in Project 3 (hint: ArgoCD sync events, Sloth burn
  rate), and why do they belong on an *overview*?
- The `service` variable collapsed many potential dashboards into one. What is the
  maintenance cost difference between 1 templated board and 50 copies?

## Stretch goals (optional)

- Install `jsonnet` and `jsonnet-bundler`, vendor Grafonnet
  (`jb install github.com/grafana/grafonnet/gen/grafonnet-latest@main`), and render
  [`platform-overview.jsonnet`](./platform-overview.jsonnet) yourself; diff it against
  the committed JSON.
- Add a **logs** panel (Loki) and a **traces** panel (Tempo) to the board to make it a
  true three-pillar overview (you ran both in Modules 11.4–11.5).
- Add a Grafana **alert rule** on the SLO burn-rate panel and route it to a webhook
  contact point; you will formalize burn-rate alerting in Module 11.7.
