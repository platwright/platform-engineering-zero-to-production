# Lab — Diagnose and fix five broken workloads

> You'll be handed five pre-broken manifests, one for each classic Kubernetes failure
> mode. For each, run the debugging workflow (state → describe → events → logs),
> identify the root cause from the evidence, fix the manifest, and verify. Try each
> yourself before opening the solutions. Local kind cluster only — no cloud cost.

**Estimated time:** ~60–90 minutes
**Type:** Debug
**Deliverable:** All five workloads healthy, with a one-line root cause and fix
written down for each.

## Objectives

- Apply a repeatable diagnosis workflow instead of guessing.
- Recognize the signatures of `OOMKilled`, `ImagePullBackOff`, `Pending`,
  `CrashLoopBackOff`, and an unreachable Service.
- Fix each root cause and confirm recovery.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter files here: [`kind-config.yaml`](./kind-config.yaml),
  [`01-oomkilled.yaml`](./01-oomkilled.yaml),
  [`02-imagepullbackoff.yaml`](./02-imagepullbackoff.yaml),
  [`03-pending-toleration.yaml`](./03-pending-toleration.yaml),
  [`04-crashloop-env.yaml`](./04-crashloop-env.yaml), and
  [`05-service-selector.yaml`](./05-service-selector.yaml).

## Setup

Create the cluster, then reserve the last worker as a "gpu" node (this is the taint
that Failure 3 fails to tolerate):

```bash
kind create cluster --config kind-config.yaml

GPU_NODE=$(kubectl get nodes -o name | grep worker | tail -1)
kubectl taint "$GPU_NODE" dedicated=gpu:NoSchedule --overwrite
kubectl label "$GPU_NODE" workload=gpu --overwrite
kubectl get nodes --show-labels | grep workload=gpu
```

Keep this workflow in front of you for every failure:

```text
1. kubectl get pods            → what STATE? (names the class of problem)
2. kubectl describe <obj>      → read Conditions + Events (the cause, in English)
3. kubectl logs --previous     → the app's last words (for CrashLoopBackOff)
4. kubectl exec / debug        → confirm inside the container
```

## Steps

1. **Failure 1 — OOMKilled.** Apply it, watch it restart, and diagnose:

   ```bash
   kubectl apply -f 01-oomkilled.yaml
   kubectl get pod oom-app -w              # RESTARTS climbs; Ctrl+C
   kubectl describe pod oom-app | grep -A3 'Last State'
   ```

   Identify why it's being killed, then fix `01-oomkilled.yaml`, re-apply
   (`kubectl delete pod oom-app; kubectl apply -f 01-oomkilled.yaml`), and confirm
   it stays `Running`.

2. **Failure 2 — ImagePullBackOff.** Apply it and read the pull error:

   ```bash
   kubectl apply -f 02-imagepullbackoff.yaml
   kubectl get pods -l app=web-img
   kubectl describe pod -l app=web-img | sed -n '/Events/,$p'
   ```

   Fix the manifest and re-apply (`kubectl apply -f 02-imagepullbackoff.yaml` triggers
   a new rollout); confirm the Pod reaches `Running`.

3. **Failure 3 — Pending.** Apply it and ask the scheduler why it won't place the Pod:

   ```bash
   kubectl apply -f 03-pending-toleration.yaml
   kubectl get pod gpu-job
   kubectl describe pod gpu-job | sed -n '/Events/,$p'
   ```

   The event names the blocker. Fix the manifest, re-apply
   (`kubectl delete pod gpu-job; kubectl apply -f 03-pending-toleration.yaml`), and
   confirm it schedules onto the gpu node (`kubectl get pod gpu-job -o wide`).

4. **Failure 4 — CrashLoopBackOff.** Apply it, then get the *previous* container's
   logs — the current one just restarted:

   ```bash
   kubectl apply -f 04-crashloop-env.yaml
   kubectl get pods -l app=worker
   kubectl logs deploy/worker --previous
   ```

   The log line is explicit. Fix the manifest, re-apply, and confirm `Running` with a
   clean log (`kubectl logs deploy/worker`).

5. **Failure 5 — unreachable Service.** The Pods are healthy but the Service returns
   nothing. Find the break without assuming it's "the network":

   ```bash
   kubectl apply -f 05-service-selector.yaml
   kubectl get pods -l app=shop-api -o wide
   kubectl get endpointslices -l kubernetes.io/service-name=shop-api -o wide   # empty!
   kubectl get svc shop-api -o jsonpath='{.spec.selector}{"\n"}'
   kubectl get pods --show-labels -l lab=debug
   ```

   Compare the Service selector to the Pod labels, fix the mismatch, re-apply, and
   confirm the EndpointSlice now lists Pod IPs. Then prove it's reachable:

   ```bash
   kubectl run tmp --image=nicolaka/netshoot:v0.13 --restart=Never -it --rm -- \
     curl -s shop-api/health && echo " <- 200 OK"
   ```

6. **Confirm everything is green.**

   ```bash
   kubectl get pods -l lab=debug -o wide
   kubectl get endpointslices -l kubernetes.io/service-name=shop-api
   ```

<details>
<summary>Solutions (try each failure yourself first)</summary>

**Failure 1 — OOMKilled.** `describe` shows `Last State: Terminated, Reason:
OOMKilled` (exit code 137). The app allocates ~128 MB but the memory **limit** is
32Mi, so the kernel kills it. Raise the limit above real usage:

```yaml
      resources:
        requests:
          memory: 128Mi
        limits:
          memory: 256Mi
```

**Failure 2 — ImagePullBackOff.** Events show `Failed to pull image
"nginx:1.27-thistagdoesnotexist": ... not found`. The tag doesn't exist. Correct it:

```yaml
          image: nginx:1.27
```

**Failure 3 — Pending.** Events show `0/3 nodes are available: 1 node(s) had
untolerated taint {dedicated: gpu} ...` (the other nodes don't match the
`workload=gpu` selector). The Pod targets the tainted gpu node but doesn't tolerate
it. Add the toleration:

```yaml
spec:
  nodeSelector:
    workload: gpu
  tolerations:
    - key: dedicated
      value: gpu
      effect: NoSchedule
  containers:
    - name: app
      image: nginx:1.27
```

**Failure 4 — CrashLoopBackOff.** `kubectl logs deploy/worker --previous` prints
`FATAL: REQUIRED_TOKEN environment variable is not set`. The entrypoint requires it.
Provide the env var:

```yaml
          env:
            - name: REQUIRED_TOKEN
              value: "demo-not-a-real-secret"
```

**Failure 5 — unreachable Service.** The EndpointSlice is empty though Pods are
`Running`. The Pods are labeled `app: shop-api` but the Service selector is `app:
shop`. Fix the selector to match:

```yaml
spec:
  selector:
    app: shop-api
```

In every case the evidence (state + events + logs) named the cause before any change
— that's the whole point of the workflow.

</details>

## Expected result

All five workloads are healthy: `oom-app` and `gpu-job` are `Running`, the `web` and
`worker` Deployments are rolled out, and `shop-api` has a populated EndpointSlice and
answers over curl. For each, you can state the one-line root cause and the fix.

## Cleanup

> Tear the cluster down so it stops holding memory. Never skip this.

```bash
kind delete cluster --name pe-debug
```

## Reflection

- For which failures was `kubectl describe` enough, and for which did you need
  `kubectl logs --previous`? What does that tell you about where each kind of problem
  surfaces?
- Failure 5 looked like a networking problem but wasn't. What's the first thing to
  check before ever suspecting the network?
- Three of these (OOMKilled, Pending, unreachable) map directly to earlier modules in
  this phase. Which modules, and why is debugging "the fundamentals, proven"?

## Stretch goals (optional)

- Use `kubectl debug` to attach an ephemeral container to a running Pod and inspect
  its filesystem and environment without a shell in the app image.
- Break a sixth workload yourself (e.g. an unbound PVC that leaves a Pod `Pending`)
  and hand it to a teammate to diagnose with the workflow.
- Write a short runbook: for each of the five signatures, the one command that
  confirms it and the usual fix — the start of a self-service debugging guide.
