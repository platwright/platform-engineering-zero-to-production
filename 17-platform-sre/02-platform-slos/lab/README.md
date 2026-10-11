# Lab — A platform SLO pack with Sloth

> You will turn four platform services into SLOs: write them as Sloth
> `PrometheusServiceLevel` specs, generate their multi-window burn-rate alerts, and
> draft a one-page **error-budget policy** that states what happens at each burn tier.
> The deliverable is an SLO pack you could publish to the teams that depend on you.
> Core steps are offline and free; an optional extension loads the rules into a live
> cluster.

**Estimated time:** ~50–70 minutes (core) · +30 (optional live extension)
**Type:** Build
**Deliverable:** Four generated `PrometheusRule` files plus a filled-in
[`error-budget-policy.md`](./error-budget-policy.md).

## Objectives

- Write platform SLOs (availability and latency) as Sloth specs.
- Generate recording rules and multi-window burn-rate alerts for each.
- Draft an error-budget policy that distinguishes freeze from investigate.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker. The optional extension also needs
  [kind](https://kind.sigs.k8s.io/) and [Helm](https://helm.sh/).
- [Module 17.2](../README.md) and [Module 11.7](../../../11-observability-engineering/07-slos-and-error-budgets/)
  theory.
- Starter specs in this folder:
  [`gitops-sync-latency-slo.yaml`](./gitops-sync-latency-slo.yaml),
  [`argocd-availability-slo.yaml`](./argocd-availability-slo.yaml),
  [`secret-propagation-slo.yaml`](./secret-propagation-slo.yaml),
  [`build-pipeline-slo.yaml`](./build-pipeline-slo.yaml), and the policy template
  [`error-budget-policy.md`](./error-budget-policy.md).

## Steps

1. **Read the four specs.** Open each starter file. Note that two are **availability**
   SLOs (Argo CD, secret propagation — good ÷ total events) and two are **latency**
   SLOs (GitOps sync, build pipeline — good = events under a histogram bucket). Each
   targets a *platform* service whose users are other teams.

   ```bash
   cd 17-platform-sre/02-platform-slos/lab
   ls *.yaml
   ```

2. **Generate the Argo CD availability rules.** Expand one spec into a full
   `PrometheusRule`:

   ```bash
   docker run --rm -v "${PWD}:/data" ghcr.io/slok/sloth:v0.16.0 \
     generate -i /data/argocd-availability-slo.yaml -o /data/argocd-availability-rules.yaml
   ```

   (On Windows PowerShell use `-v "${PWD}:/data"`; on cmd.exe use `-v "%cd%:/data"`.)

3. **Generate the other three.** Repeat for each spec — or loop:

   ```bash
   for f in gitops-sync-latency argocd-availability secret-propagation build-pipeline; do
     docker run --rm -v "${PWD}:/data" ghcr.io/slok/sloth:v0.16.0 \
       generate -i "/data/${f}-slo.yaml" -o "/data/${f}-rules.yaml"
   done
   ```

4. **Read a latency SLO's output.** Open `gitops-sync-latency-rules.yaml`. Find the
   SLI recording rules at each window and confirm the burn-rate alerts reference the
   60s bucket logic. This is the Google SRE method applied to *your* GitOps
   controller, generated for you.

5. **Compare targets and budgets.** Notice the budgets differ by target: a 99.9% SLO
   (Argo CD) has a tiny budget, while a 95% SLO (sync latency, builds) has a large
   one. The stricter target buys less room for failure — which is why only
   critical-path services get the strict numbers.

6. **Draft the error-budget policy.** Open [`error-budget-policy.md`](./error-budget-policy.md)
   and fill it in: for each service, what a **page** (fast burn) triggers (freeze
   platform changes + respond) versus a **ticket** (slow burn) triggers (investigate +
   hold risky changes), who declares a freeze, and how it is communicated to teams.
   This document is as important as the rules — it decides what the alerts *mean*.

7. **Tighten one objective and regenerate.** Change the build pipeline `objective`
   from `95.0` to `97.0` and re-run its generate. Diff the output: the budget shrank
   and the alerts now trip on smaller slowdowns. One number changed the platform's
   reliability posture — SLOs as code.

8. **(Optional) Load into a live cluster.** Apply the generated rules to a real
   Prometheus so they appear under Rules/Alerts:

   ```bash
   kind create cluster --name pe-platform-slo
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update
   helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
     --version 65.5.1 --namespace monitoring --create-namespace
   kubectl apply -n monitoring -f argocd-availability-rules.yaml
   # label so the Prometheus Operator loads it
   kubectl -n monitoring label prometheusrule argocd release=kube-prom-stack --overwrite
   kubectl -n monitoring get prometheusrule
   ```

   The rules will not fire without Argo CD metrics flowing, but you will see them
   registered under Prometheus's **Rules** page — proof the pack is valid.

## Expected result

Four `*-rules.yaml` files, each a valid `PrometheusRule` with SLI recording rules at
every window and multi-window `page`/`ticket` burn-rate alerts. A completed
`error-budget-policy.md` that clearly separates the freeze response (fast burn) from
the investigate response (slow burn) and names who communicates status to teams.
Tightening an objective visibly shrinks the budget and lowers the thresholds.

## Cleanup

> Remove generated files and tear down the optional cluster. Never skip this.

```bash
rm -f *-rules.yaml
# only if you ran the optional extension:
helm uninstall kube-prom-stack --namespace monitoring --ignore-not-found
kind delete cluster --name pe-platform-slo
```

## Reflection

- Two of these SLOs are latency, not availability. Why would an "all green on
  availability" dashboard still be failing the teams that depend on the platform?
- Your error-budget policy freezes *platform changes* on a fast burn but keeps teams'
  deploys flowing. Why is that distinction the whole point for a platform team?
- The cluster API server SLO in the lesson was inherited from the cloud provider's
  SLA. Why can you not simply pick a higher number for it?

## Stretch goals (optional)

- Add a second SLO to the Argo CD spec for **sync success** (errored syncs ÷ total
  syncs) alongside API availability, and regenerate.
- Wire one generated `page` alert to an Alertmanager receiver and confirm routing by
  the `severity` label, as you did in Module 11.7.
- Publish the four objectives as a small status table (service, SLO, budget
  remaining) — the seed of the platform status page from the lesson.
