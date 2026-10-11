# Lab — SLOs and burn-rate alerts with Sloth

> You will define an SLO as a Sloth `PrometheusServiceLevel`, then run `sloth generate`
> to expand it into a full `PrometheusRule` — SLI recording rules at every window plus
> **multi-window, multi-burn-rate** `page`/`ticket` alerts. Reading that generated
> output is how the Google SRE method stops being theory. Core steps are offline and
> free; an optional extension applies it to a live cluster.

**Estimated time:** ~45–60 minutes (core) · +30 (optional live extension)
**Type:** Build
**Deliverable:** A generated `PrometheusRule` containing SLI recording rules and
multi-window burn-rate alerts, and an understanding of each tier.

## Objectives

- Write an SLO declaratively as a Sloth spec.
- Generate the recording and multi-window burn-rate alert rules from it.
- Read and explain the burn-rate tiers in the output.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker. The optional extension also needs
  [kind](https://kind.sigs.k8s.io/) and [Helm](https://helm.sh/).
- [Module 11.7](../README.md) theory.
- Starter files in this folder: [`argocd-api-slo.yaml`](./argocd-api-slo.yaml)
  (faithful to the course outline), [`sample-app-slo.yaml`](./sample-app-slo.yaml)
  (runnable against Module 11.3's app), [`burn-rate-alerts.yaml`](./burn-rate-alerts.yaml)
  (a hand-written multi-window example to compare against), and
  [`slo-queries.promql`](./slo-queries.promql).

## Steps

1. **Read the SLO spec.** Open [`argocd-api-slo.yaml`](./argocd-api-slo.yaml). It
   declares one thing: `argocd` availability at **99.9%**, with an SLI defined as
   errored syncs ÷ total syncs. Note the `{{.window}}` placeholder — Sloth fills it in
   for every window it needs.

2. **Generate the rules (offline).** Run Sloth in Docker to expand the spec into a
   `PrometheusRule`:

   ```bash
   docker run --rm -v "${PWD}:/data" ghcr.io/slok/sloth:v0.16.0 \
     generate -i /data/argocd-api-slo.yaml -o /data/argocd-api-rules.yaml
   ```

   (On Windows PowerShell, use `-v "${PWD}:/data"`; on cmd.exe use `-v "%cd%:/data"`.)

3. **Read the recording rules.** Open the generated `argocd-api-rules.yaml`. Find the
   SLI error-ratio recording rules computed at **multiple windows** (`5m`, `30m`,
   `1h`, `2h`, `6h`, `1d`, `3d`) and the metadata rules (objective, error budget).
   These are the pre-computed series the alerts consume.

4. **Read the burn-rate alerts.** Scroll to the alert rules. You will see a **page**
   alert and a **ticket** alert, each combining a short and a long window. Match them to
   the lesson's table:

   ```text
   page   : fast burn (14.4x over 1h & 5m) OR (6x over 6h & 30m)
   ticket : slow burn (3x over 1d & 2h)    OR (1x over 3d & 6h)
   ```

   This is multi-window, multi-burn-rate alerting, generated for you from one spec.

5. **Compare to the hand-written version.** Open
   [`burn-rate-alerts.yaml`](./burn-rate-alerts.yaml). It expresses the same method by
   hand for the sample app, so you can see exactly what Sloth automates — and why you
   would rather not maintain it per service.

6. **Tighten the objective and regenerate.** Change `objective: 99.9` to `99.95` in
   [`argocd-api-slo.yaml`](./argocd-api-slo.yaml) and re-run step 2. Diff the output:
   the error budget shrank and the burn-rate thresholds now trip on smaller error
   ratios. One number changed the whole alerting posture — SLOs as code.

7. **(Optional) Make it fire on a live cluster.** Generate from the runnable SLO and
   apply it to a real stack:

   ```bash
   kind create cluster --name pe-slo
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
     --version 65.5.1 --namespace monitoring --create-namespace
   kubectl apply -n monitoring -f ../../03-metrics-with-prometheus/lab/sample-app.yaml
   kubectl apply -n monitoring -f ../../03-metrics-with-prometheus/lab/servicemonitor.yaml

   docker run --rm -v "${PWD}:/data" ghcr.io/slok/sloth:v0.16.0 \
     generate -i /data/sample-app-slo.yaml -o /data/sample-app-rules.yaml
   kubectl apply -n monitoring -f sample-app-rules.yaml
   # Sloth preserves the input name; label the generated rule so the Operator loads it:
   kubectl -n monitoring get prometheusrule
   kubectl -n monitoring label prometheusrule sample-app release=kube-prom-stack --overwrite
   ```

   Port-forward Prometheus (`:9090`), open **Alerts**, and drive errors with the load
   loop from Module 11.3 (half the traffic hits `/err`) to push the SLI down and watch
   a burn-rate alert move toward firing.

## Expected result

`argocd-api-rules.yaml` is a valid `PrometheusRule` containing SLI recording rules at
seven windows, SLO metadata rules, and two multi-window burn-rate alerts (`page` and
`ticket`). Tightening the objective visibly shrinks the budget and lowers the alert
thresholds. In the optional extension, the generated rules appear under Prometheus's
Rules/Alerts pages.

## Cleanup

> Remove generated files, and tear down the optional cluster. Never skip this.

```bash
rm -f argocd-api-rules.yaml sample-app-rules.yaml
# only if you ran the optional extension:
helm uninstall kube-prom-stack --namespace monitoring --ignore-not-found
kind delete cluster --name pe-slo
```

## Reflection

- You changed one number (the objective) and the alerting thresholds moved with it.
  Why is that safer than hand-editing four alert expressions per service?
- The page alert needs a short **and** a long window to be true. Which problem does
  each window solve, and what happens to the alert when the incident ends?
- These SLOs target *platform* services (Argo CD). Why should a platform publish SLOs
  for the tools it operates, not just expect app teams to have them?

## Stretch goals (optional)

- Add a **latency** SLO to [`sample-app-slo.yaml`](./sample-app-slo.yaml) using the
  `http_request_duration_seconds_bucket` histogram (good = requests under 300ms) and
  regenerate.
- Wire one generated alert to an Alertmanager receiver and confirm routing by severity
  label (`page` vs `ticket`).
- Explore **Pyrra** as an alternative that reconciles SLO objects in-cluster and shows
  a budget/burn dashboard, and compare its model to Sloth's generate step.
