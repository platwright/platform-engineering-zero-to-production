# Lab — PromQL against a scraped service

> You will stand up `kube-prometheus-stack` on kind, deploy a sample service,
> declare a **ServiceMonitor** so Prometheus discovers and scrapes it, drive some
> traffic, and answer three real questions in PromQL — **error rate**, **p99
> latency**, and **CPU by namespace** — then pre-compute one with a recording rule.

**Estimated time:** ~60–75 minutes
**Type:** Build
**Deliverable:** A scraped target shown `up` in Prometheus and four working PromQL
expressions (error ratio, p99 latency, namespace CPU, and a recorded rule).

## Objectives

- Install the Prometheus Operator stack and confirm a target is scraped.
- Write PromQL for RED signals and a USE signal.
- Add a recording rule and query the pre-computed series.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), and
  [Helm](https://helm.sh/).
- [Module 11.3](../README.md) theory.
- Starter files in this folder: [`sample-app.yaml`](./sample-app.yaml),
  [`servicemonitor.yaml`](./servicemonitor.yaml),
  [`prometheus-rules.yaml`](./prometheus-rules.yaml), and
  [`queries.promql`](./queries.promql).

## Steps

1. **Create a cluster and install the stack.** This pulls several images; give it a
   few minutes:

   ```bash
   kind create cluster --name pe-prometheus
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
     --version 65.5.1 --namespace monitoring --create-namespace
   kubectl -n monitoring rollout status deploy/kube-prom-stack-kube-prometheus-operator
   ```

2. **Deploy the sample service and scrape it.** The app returns `200` on `/` and
   `404` on `/err`, and exposes a latency histogram — ideal for RED PromQL:

   ```bash
   kubectl apply -n monitoring -f sample-app.yaml
   kubectl apply -n monitoring -f servicemonitor.yaml
   kubectl -n monitoring rollout status deploy/prometheus-example-app
   ```

   The ServiceMonitor carries the label `release: kube-prom-stack` so the stack's
   Prometheus selects it. The Operator regenerates Prometheus's scrape config for you.

3. **Generate traffic.** Run a loop that hits both endpoints so counters and the
   histogram fill with 200s and 404s:

   ```bash
   kubectl -n monitoring run load --image=busybox:1.36 --restart=Never -- \
     /bin/sh -c 'while true; do \
       wget -q -O- http://prometheus-example-app:8080/ >/dev/null; \
       wget -q -O- http://prometheus-example-app:8080/err >/dev/null; \
       sleep 0.2; done'
   ```

4. **Open Prometheus and confirm the target is `up`.** Port-forward the UI:

   ```bash
   kubectl -n monitoring port-forward svc/kube-prom-stack-kube-prometheus-prometheus 9090:9090
   ```

   Browse to [http://localhost:9090/targets](http://localhost:9090/targets) and find
   `serviceMonitor/monitoring/prometheus-example-app` in state **UP**. If it is
   missing, the ServiceMonitor label or the Service port name is wrong (see the
   debugging exercise in the lesson).

5. **Ask the questions.** In the **Graph** tab, run each expression from
   [`queries.promql`](./queries.promql). The three headliners:

   ```promql
   # error ratio (this app emits 404s on /err)
   sum(rate(http_requests_total{code=~"4..|5.."}[5m]))
     / sum(rate(http_requests_total[5m]))

   # p99 request latency across all instances
   histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket[5m])))

   # CPU usage by namespace (a USE signal from cAdvisor)
   sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))
   ```

   Give the rate windows ~1–2 minutes of traffic to produce non-zero values.

6. **Pre-compute with a recording rule.** Apply the `PrometheusRule` and let it
   evaluate (~1 minute):

   ```bash
   kubectl apply -n monitoring -f prometheus-rules.yaml
   ```

   Then query the recorded series directly — note it is instant and cheap because the
   heavy expression already ran:

   ```promql
   job:http_request_errors:ratio_rate5m
   ```

7. **(Optional) See it in Grafana.** Port-forward Grafana and explore the same
   queries; you will build dashboards properly in
   [Module 11.6](../../06-grafana-dashboards/):

   ```bash
   kubectl -n monitoring port-forward svc/kube-prom-stack-grafana 3000:80
   # user: admin   password: prom-operator
   ```

## Expected result

The Targets page shows `prometheus-example-app` as `up`. The error-ratio query
returns roughly `0.5` (half the requests go to `/err`), the p99 query returns a small
positive number of seconds, and the namespace query lists per-namespace CPU. After
the rule evaluates, `job:http_request_errors:ratio_rate5m` returns the same ratio as
a single pre-computed series.

## Cleanup

> Always tear down — this stack is resource-hungry. Never skip this.

```bash
kubectl -n monitoring delete pod load --ignore-not-found
helm uninstall kube-prom-stack --namespace monitoring --ignore-not-found
kind delete cluster --name pe-prometheus
```

## Reflection

- You never edited Prometheus's config file directly — you applied a ServiceMonitor.
  Why is declaring scrape targets as Kubernetes objects a better fit for a platform
  than a central config file?
- The error-ratio query divides two `rate()`s rather than counting raw errors. Why is
  a *ratio of rates* more useful for alerting than a raw error count?
- The recording rule turned a heavy expression into one cheap series. Which of your
  queries would you record before wiring it to an alert or a dashboard, and why?

## Stretch goals (optional)

- Add an **alerting rule** to [`prometheus-rules.yaml`](./prometheus-rules.yaml) that
  fires when the error ratio exceeds `0.1` for 5 minutes, and watch it appear in the
  Prometheus **Alerts** tab.
- Break the ServiceMonitor on purpose: change its `release` label, re-apply, and watch
  the target disappear from the Targets page. Fix it and watch it return.
- Add a `sample_limit` to the ServiceMonitor and reason about what would happen if the
  app suddenly exposed a high-cardinality label.
