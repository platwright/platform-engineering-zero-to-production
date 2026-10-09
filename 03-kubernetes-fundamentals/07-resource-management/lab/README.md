# Lab — Quotas and autoscaling under load

> You'll put defaults and a budget on a namespace (and watch an over-sized Pod get
> rejected and a resource-less Pod get defaults), then install metrics-server,
> autoscale a Deployment with an HPA, and drive real CPU load to watch replicas scale
> out and back in. Local kind cluster only — no cloud cost.

**Estimated time:** ~50–65 minutes
**Type:** Build
**Deliverable:** A namespace with enforced LimitRange + ResourceQuota, and an HPA you
watched scale a Deployment under load.

## Objectives

- Enforce per-container defaults/bounds (LimitRange) and a namespace budget
  (ResourceQuota).
- See admission reject an over-limit Pod and inject defaults into a bare Pod.
- Autoscale a Deployment on CPU and observe scale-up and scale-down.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). Internet access to pull
  metrics-server.
- Starter manifests here: [`limitrange.yaml`](./limitrange.yaml),
  [`resourcequota.yaml`](./resourcequota.yaml),
  [`deployment-resources.yaml`](./deployment-resources.yaml), and
  [`hpa.yaml`](./hpa.yaml).

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-resources
   ```

2. **Apply namespace guardrails.** Create `team-a`, then its LimitRange and
   ResourceQuota:

   ```bash
   kubectl create namespace team-a
   kubectl apply -f limitrange.yaml
   kubectl apply -f resourcequota.yaml
   kubectl describe resourcequota team-budget -n team-a
   ```

3. **See defaults injected into a bare Pod.** Run a Pod with **no** resources; the
   LimitRange fills them in, so it's Burstable, not BestEffort:

   ```bash
   kubectl run demo --image=nginx -n team-a
   kubectl get pod demo -n team-a -o jsonpath='{.status.qosClass}{"  "}{.spec.containers[0].resources}{"\n"}'
   ```

   You should see the default requests (`100m`/`64Mi`) and limits (`200m`/`128Mi`).

4. **See admission reject an over-sized Pod.** Ask for more CPU than the LimitRange
   `max` (1 CPU) — it's refused before it ever schedules:

   ```bash
   kubectl run toobig --image=nginx -n team-a \
     --overrides='{"spec":{"containers":[{"name":"toobig","image":"nginx","resources":{"requests":{"cpu":"2"},"limits":{"cpu":"2"}}}]}}'
   ```

   Expect a `forbidden: maximum cpu usage per Container is 1` error. The quota and
   limits are doing their job. Clean up the demo Pod:

   ```bash
   kubectl delete pod demo -n team-a --ignore-not-found
   ```

5. **Install metrics-server (HPA needs a metrics source).** On kind you must allow
   its insecure kubelet TLS:

   ```bash
   kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
   kubectl patch deployment metrics-server -n kube-system --type=json \
     -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
   kubectl rollout status deployment metrics-server -n kube-system --timeout=120s
   kubectl top nodes        # works once metrics-server is ready (may take ~30s)
   ```

6. **Deploy the autoscaling target and its HPA** (in the default namespace):

   ```bash
   kubectl apply -f deployment-resources.yaml
   kubectl rollout status deployment/web
   kubectl apply -f hpa.yaml
   kubectl get hpa web          # TARGETS shows cpu usage once metrics flow in
   ```

7. **Generate load and watch it scale out.** In one terminal, watch the HPA; in
   another, hammer the Service from an in-cluster loop:

   ```bash
   kubectl get hpa web -w       # terminal A: keep running
   ```

   ```bash
   kubectl run load --image=busybox:1.36 --restart=Never -- \
     /bin/sh -c "while true; do wget -q -O- http://web; done"   # terminal B
   ```

   Within a minute or two, `TARGETS` climbs past 50% and `REPLICAS` rises toward the
   max of 10. Confirm the new Pods:

   ```bash
   kubectl get pods -l app=web
   ```

8. **Stop the load and watch it scale back in.** Delete the load generator; after the
   stabilization window (a few minutes) replicas drop back toward 1:

   ```bash
   kubectl delete pod load
   kubectl get hpa web -w       # REPLICAS falls back down; Ctrl+C when settled
   kubectl describe hpa web | grep -A6 Events   # scale up/down events
   ```

## Expected result

A namespace that rejects over-sized Pods and auto-defaults bare ones, metrics-server
feeding utilization, and an HPA that scaled `web` out under CPU load and back in when
it stopped. You've seen both halves of resource management: guardrails and
autoscaling.

## Cleanup

> Tear everything down so the cluster stops holding memory. Never skip this.

```bash
kubectl delete -f hpa.yaml --ignore-not-found
kubectl delete -f deployment-resources.yaml --ignore-not-found
kubectl delete namespace team-a --ignore-not-found
kind delete cluster --name pe-resources
```

## Reflection

- The HPA scales on CPU *utilization*, a percentage of the request. Why would the HPA
  read `<unknown>` if you forgot to set a CPU request on `web`?
- Scale-up was fast but scale-down was slow. Why is a stabilization window on
  scale-down a good idea for a real service?
- A ResourceQuota blocks a team from exceeding its budget. How does that protect
  *other* teams on the same cluster?

## Stretch goals (optional)

- Fill the `team-a` quota: deploy enough Pods to hit `requests.cpu: "1"` and watch the
  next Pod be rejected with an `exceeded quota` message.
- Lower the HPA `averageUtilization` to `20` and observe it scale out at lighter load.
- Run `kubectl top pods` during the load test to watch real CPU usage climb alongside
  the replica count.
