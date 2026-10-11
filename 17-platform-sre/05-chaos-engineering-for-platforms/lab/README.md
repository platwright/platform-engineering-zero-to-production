# Lab — Three chaos experiments against the platform

> You will install Chaos Mesh on a local cluster and run three experiments against
> platform components — **kill a third of Argo CD's pods**, **add 500ms latency to
> Prometheus**, and **delete the External Secrets Operator pod** — each framed by a
> steady-state hypothesis. For every experiment you record whether the SLO held,
> whether alerts fired, and whether recovery worked. Experiment 1 runs free on kind;
> 2 and 3 add their components or are reasoned through.

**Estimated time:** ~60–80 minutes
**Type:** Build / experiment
**Deliverable:** A completed [`chaos-results-worksheet.md`](./chaos-results-worksheet.md)
for all three experiments.

## Objectives

- Install Chaos Mesh and establish a measurable steady state.
- Inject pod-kill and network-latency faults with controlled blast radius.
- Judge each experiment on three layers: system, signals, and humans.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, [kind](https://kind.sigs.k8s.io/), `kubectl`, and [Helm](https://helm.sh/).
- [Module 17.5](../README.md) theory.
- Starter manifests in this folder:
  [`exp1-argocd-pod-kill.yaml`](./exp1-argocd-pod-kill.yaml),
  [`exp2-prometheus-latency.yaml`](./exp2-prometheus-latency.yaml),
  [`exp3-eso-pod-kill.yaml`](./exp3-eso-pod-kill.yaml), and
  [`chaos-results-worksheet.md`](./chaos-results-worksheet.md).

## Steps

1. **Create a cluster and install Chaos Mesh.** Chaos Mesh is free and runs locally:

   ```bash
   kind create cluster --name pe-chaos
   kubectl create namespace chaos-testing
   helm repo add chaos-mesh https://charts.chaos-mesh.org
   helm repo update
   helm install chaos-mesh chaos-mesh/chaos-mesh \
     --namespace chaos-testing --version 2.6.3 \
     --set chaosDaemon.runtime=containerd \
     --set chaosDaemon.socketPath=/run/containerd/containerd.sock
   kubectl -n chaos-testing rollout status deploy/chaos-controller-manager --timeout=180s
   ```

2. **Install Argo CD and reach steady state.** This is the target for experiment 1:

   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.12.4/manifests/install.yaml
   kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=180s
   kubectl apply -n argocd -f - <<'EOF'
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: guestbook
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: https://github.com/argoproj/argocd-example-apps.git
       targetRevision: HEAD
       path: guestbook
     destination:
       server: https://kubernetes.default.svc
       namespace: default
     syncPolicy:
       automated: {}
   EOF
   kubectl -n argocd get application guestbook -o wide   # steady state: Synced/Healthy
   ```

3. **State the hypothesis, then run experiment 1.** Record the steady state in the
   worksheet, then kill a third of Argo CD's pods:

   ```bash
   kubectl -n argocd get pods
   kubectl apply -f exp1-argocd-pod-kill.yaml
   # observe: a third terminate and are recreated
   kubectl -n argocd get pods -w
   ```

4. **Observe and judge experiment 1.** While pods churn, check the three layers:

   ```bash
   # system: did the SLI hold? (app still Synced/Healthy)
   kubectl -n argocd get application guestbook -o wide
   # signals: in a full stack, did a burn-rate alert fire or stay quiet appropriately?
   # humans:  was a runbook needed? did recovery need intervention?
   kubectl -n argocd get pods      # back to Running = self-healed
   ```

   Record the result (held / broke, alert behavior, recovery time). Remove the
   experiment: `kubectl delete -f exp1-argocd-pod-kill.yaml`.

5. **Experiment 2 — latency to Prometheus.** If you installed a monitoring stack (from
   Phase 11), inject the latency; otherwise read the manifest and reason through the
   hypothesis:

   ```bash
   # optional component install:
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install kube-prom-stack prometheus-community/kube-prometheus-stack \
     --version 65.5.1 -n monitoring --create-namespace
   kubectl -n monitoring rollout status deploy/kube-prom-stack-grafana --timeout=180s

   kubectl apply -f exp2-prometheus-latency.yaml
   # observe Grafana: slower queries / timeout warnings, but not a total blackout;
   # confirm alert evaluation still runs.
   kubectl delete -f exp2-prometheus-latency.yaml   # (or let its duration expire)
   ```

   Record whether monitoring **degraded gracefully** (hypothesis held) or went blind.

6. **Experiment 3 — delete the ESO pod.** If you installed External Secrets Operator
   (from Phase 10/13), kill its controller; otherwise reason through the hypothesis:

   ```bash
   # optional component install:
   helm repo add external-secrets https://charts.external-secrets.io
   helm install external-secrets external-secrets/external-secrets \
     -n external-secrets --create-namespace
   kubectl -n external-secrets rollout status deploy/external-secrets --timeout=180s

   # note the existing managed Secrets, then kill the controller
   kubectl apply -f exp3-eso-pod-kill.yaml
   kubectl -n external-secrets get pods -w     # recreated within ~30s
   # existing Secrets should still exist; new syncs retry after restart
   kubectl delete -f exp3-eso-pod-kill.yaml
   ```

   Record whether existing secrets survived and the controller recovered within ~30s.

7. **Complete the worksheet.** For all three experiments, fill in
   [`chaos-results-worksheet.md`](./chaos-results-worksheet.md): hypothesis, result
   (held/broke), and the three-layer judgment (system / signals / humans), plus any
   weakness found and the follow-up action (a fix or a new runbook).

## Expected result

Experiment 1: a third of Argo CD pods are killed and recreated while `guestbook` stays
`Synced/Healthy` — the hypothesis holds and Argo CD self-heals. Experiments 2 and 3
(run or reasoned): monitoring degrades gracefully rather than going blind, and ESO
recovers within ~30s with existing secrets intact. The worksheet records each result
and at least one follow-up action for any weakness or missing alert/runbook.

## Cleanup

> Remove the experiments first, then the cluster. Never leave chaos running.

```bash
kubectl delete -f exp1-argocd-pod-kill.yaml --ignore-not-found
kubectl delete -f exp2-prometheus-latency.yaml --ignore-not-found
kubectl delete -f exp3-eso-pod-kill.yaml --ignore-not-found
kind delete cluster --name pe-chaos
```

## Reflection

- In experiment 1 the system survived. If **no alert would have fired**, why is that
  still a failed experiment, and what would you change?
- Each manifest has a tight selector and (for latency) a `duration`. How do those two
  fields keep a chaos experiment from becoming a real incident?
- You ran these in dev. What has to be true about your SLOs, kill switch, and team
  before you would run the same experiments against production traffic?

## Stretch goals (optional)

- Add a `duration` and a `scheduler` to experiment 1 so it becomes a recurring,
  automated resilience regression test rather than a one-shot.
- Combine experiments: run the Prometheus latency *and* the Argo CD pod-kill together
  and check whether you can still *observe* the platform during a failure.
- Write a one-page GameDay plan: the failure mode, hypothesis, roles (IC, scribe),
  abort conditions, and the three-layer scorecard you will fill in live.
