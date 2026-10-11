# Lab — Three measured cost optimizations

> You'll implement and **measure** three optimizations on a free kind cluster:
> (1) right-size five over-provisioned workloads from **VPA** recommendations,
> (2) put a dev namespace to sleep with a **scale-to-zero** CronJob, and
> (3) review a **Karpenter spot + consolidation** NodePool while computing the node
> reduction right-sizing enables. For each, you record a before/after number.

**Estimated time:** ~70–90 minutes
**Type:** Build
**Deliverable:** Before/after figures for three optimizations — right-sized requests,
a slept/woken dev namespace, and a computed node-count reduction.

## Objectives

- Install VPA, read recommendations, and right-size workloads safely.
- Schedule non-prod workloads to scale to zero and back.
- Read a production-grade spot/consolidation NodePool and reason about its effect.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/).
- Starter files here: [`overprovisioned-workloads.yaml`](./overprovisioned-workloads.yaml),
  [`vpa.yaml`](./vpa.yaml), [`right-sized-workloads.yaml`](./right-sized-workloads.yaml),
  [`scale-down-cronjob.yaml`](./scale-down-cronjob.yaml), and
  [`karpenter-nodepool-spot.yaml`](./karpenter-nodepool-spot.yaml).

## Steps

### Part A — Right-size from VPA recommendations

1. **Create a cluster and install metrics-server** (VPA's data source). kind's kubelet
   serves TLS that metrics-server must be told to trust:

   ```bash
   kind create cluster --name pe-finops-opt
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   kubectl -n kube-system patch deploy metrics-server --type=json \
     -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   kubectl -n kube-system rollout status deploy/metrics-server
   ```

2. **Install the Vertical Pod Autoscaler (recommender only).** `updateMode: "Off"` means
   VPA only *recommends* — it never mutates your pods:

   ```bash
   helm repo add fairwinds-stable https://charts.fairwinds.com/stable
   helm repo update
   helm install vpa fairwinds-stable/vpa -n vpa --create-namespace \
     --set updater.enabled=false --set admissionController.enabled=false
   kubectl -n vpa rollout status deploy/vpa-recommender
   ```

3. **Deploy five over-provisioned workloads and their VPAs.** Each requests 500m CPU /
   512Mi but does almost nothing — the classic padding:

   ```bash
   kubectl apply -f overprovisioned-workloads.yaml
   kubectl apply -f vpa.yaml
   ```

4. **Record the "before" number.** Five workloads × 500m = **2500m CPU requested**:

   ```bash
   kubectl -n team-a get deploy -o \
     custom-columns=NAME:.metadata.name,CPUREQ:'.spec.template.spec.containers[0].resources.requests.cpu'
   ```

5. **Wait ~8–10 minutes, then read the recommendations.** VPA needs usage history before
   it will suggest a target:

   ```bash
   sleep 600
   kubectl -n team-a get vpa
   kubectl -n team-a get vpa inflated-1 -o \
     jsonpath='{.status.recommendation.containerRecommendations[0].target}' ; echo
   ```

   The target will be tiny (tens of millicores) — VPA has noticed these pods are nearly
   idle. The right-sized manifest uses a value **above** that recommendation for headroom.

6. **Apply the right-sized requests and record the "after" number.** Five workloads ×
   100m = **500m CPU requested** — a 5× cut:

   ```bash
   kubectl apply -f right-sized-workloads.yaml
   kubectl -n team-a get deploy -o \
     custom-columns=NAME:.metadata.name,CPUREQ:'.spec.template.spec.containers[0].resources.requests.cpu'
   ```

   By the Module 18.2 formula, cost falls in proportion to requests: **2500m → 500m is an
   ~80% cut** in this team's CPU cost, with headroom preserved so nothing is throttled.

### Part B — Scale non-prod to zero

1. **Create a dev namespace, two dev apps, the scaler RBAC, and the schedules.**

   ```bash
   kubectl apply -f scale-down-cronjob.yaml
   kubectl -n dev get deploy        # dev-app-1 and dev-app-2, 1 replica each
   ```

2. **Trigger the nightly scale-down now** (instead of waiting for 20:00) by creating a
   Job from the CronJob:

   ```bash
   kubectl -n dev create job --from=cronjob/scale-down-dev scale-down-now
   kubectl -n dev wait --for=condition=complete job/scale-down-now --timeout=60s
   kubectl -n dev get deploy        # both now at 0/0 — zero cost overnight
   ```

3. **Trigger the morning scale-up** the same way:

   ```bash
   kubectl -n dev create job --from=cronjob/scale-up-dev scale-up-now
   kubectl -n dev wait --for=condition=complete job/scale-up-now --timeout=60s
   kubectl -n dev get deploy        # back to 1/1
   ```

   Dev runs ~45 business hours of a 168-hour week, so sleeping it off-hours removes
   roughly **two-thirds** of its cost. Record that as your second saving.

### Part C — Spot and consolidation (cloud-optional)

1. **Read the Karpenter NodePool starter.** This is the production pattern for the last
   two rungs of the ladder — spot capacity plus active consolidation:

   ```bash
   cat karpenter-nodepool-spot.yaml
   ```

   > **Applying this needs a real cloud cluster with Karpenter installed — not kind.**
   > kind's nodes are fixed Docker containers, so no provisioner can add or remove them.
   > The file is a working starter you'd use on EKS; the comments mark the placeholders
   > to replace.

2. **Measure the principle locally instead.** Consolidation turns right-sizing into
   *fewer nodes*. With ~2 allocatable CPU per node, compute the packing before and after
   Part A:

   ```bash
   # before: ceil(2500m / 2000m) = 2 nodes   |   after: ceil(500m / 2000m) = 1 node
   python3 -c "import math; print('before', math.ceil(2500/2000), 'nodes; after', math.ceil(500/2000), 'node')"
   ```

   Right-sizing (Part A) is what *lets* consolidation (Part C) remove a node — which is
   why the ladder shrinks before it packs. Record the node reduction as your third
   result.

## Expected result

- **Right-sizing:** `team-a` CPU requests drop from 2500m to 500m (~80% less), justified
  by VPA's recommendations, with headroom kept.
- **Scale-to-zero:** `dev` deployments go to `0/0` on the scale-down Job and back to
  `1/1` on scale-up — demonstrating ~two-thirds off non-prod spend.
- **Consolidation:** you can state the node-count reduction (2 → 1) that right-sizing
  enables, and explain why spot + consolidation are the cloud step.

Three optimizations, three measured results — the "Optimize" phase of FinOps, done
safely.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
kubectl delete -f scale-down-cronjob.yaml --ignore-not-found
kubectl delete -f vpa.yaml --ignore-not-found
kubectl delete -f right-sized-workloads.yaml --ignore-not-found
helm uninstall vpa -n vpa
kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --ignore-not-found
kind delete cluster --name pe-finops-opt
```

## Reflection

- Right-sizing cut requests by 80% here because the workloads were idle. On a *busy*
  service, what would stop you cutting that far, and which usage percentile would you
  target instead?
- The scale-up CronJob restored every deployment to exactly 1 replica. Why is that naïve
  for real services, and how would you preserve each one's true replica count?
- Part C needed a cloud cluster. Which of the three optimizations gave the biggest safe
  win *for free*, and what does that tell you about where to start on a real platform?

## Stretch goals (optional)

- Add a **PodDisruptionBudget** to one right-sized workload, then reason about how it
  would constrain Karpenter consolidation.
- Rewrite the scale-up CronJob to read the original replica count from an annotation the
  scale-down Job records, so waking up restores the real count.
- Install [KEDA](https://keda.sh/) and replace the CronJobs with a **cron scaler** on one
  deployment — event-driven scale-to-zero instead of imperative `kubectl scale`.
