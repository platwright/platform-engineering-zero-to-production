# Lab — An OTel Collector agent + gateway on kind

> You will deploy the OpenTelemetry Collector twice — as a **DaemonSet agent**
> (one per node, collecting node metrics and receiving app telemetry) and a
> **Deployment gateway** (the shared control point) — then push traces and metrics
> through the agent to the gateway and watch them arrive. All local on kind, free.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A running agent → gateway pipeline on kind, verified by seeing
generated traces and node metrics in the gateway's `debug` exporter output.

## Objectives

- Deploy the Collector in both **agent** (DaemonSet) and **gateway** (Deployment)
  roles with Helm.
- Forward telemetry agent → gateway and confirm the path end to end.
- Read a real Collector config and identify receivers, processors, and exporters.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), and
  [Helm](https://helm.sh/).
- [Module 11.2](../README.md) theory.
- Starter files in this folder:
  [`agent-values.yaml`](./agent-values.yaml),
  [`gateway-values.yaml`](./gateway-values.yaml),
  [`telemetrygen-job.yaml`](./telemetrygen-job.yaml),
  [`otel-collector-config.yaml`](./otel-collector-config.yaml) (standalone reference),
  and [`app.go`](./app.go) (an instrumented service sketch).

## Steps

1. **Create a cluster and add the Helm repo.**

   ```bash
   kind create cluster --name pe-otel
   helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
   helm repo update
   ```

2. **Deploy the gateway (Deployment).** It receives OTLP and prints everything via
   the `debug` exporter so you can see telemetry arrive:

   ```bash
   helm install otel-gateway open-telemetry/opentelemetry-collector \
     --version 0.108.0 -f gateway-values.yaml
   kubectl rollout status deploy/otel-gateway
   ```

3. **Deploy the agent (DaemonSet).** It collects node `hostmetrics`, receives OTLP
   from workloads on its node, and **forwards** to the gateway Service:

   ```bash
   helm install otel-agent open-telemetry/opentelemetry-collector \
     --version 0.108.0 -f agent-values.yaml
   kubectl rollout status daemonset/otel-agent
   ```

4. **Confirm the topology.** One agent Pod *per node*, a scalable gateway
   Deployment:

   ```bash
   kubectl get daemonset,deploy,pods -l app.kubernetes.io/instance=otel-agent
   kubectl get deploy,pods -l app.kubernetes.io/instance=otel-gateway
   ```

5. **Start tailing the gateway.** Leave this running in one terminal — it is where
   telemetry will appear:

   ```bash
   kubectl logs -f deploy/otel-gateway
   ```

6. **Generate telemetry into the agent.** In a second terminal, run `telemetrygen`
   to send 20 traces to the **agent's** OTLP endpoint, exercising the full path:

   ```bash
   kubectl apply -f telemetrygen-job.yaml
   kubectl wait --for=condition=complete job/telemetrygen --timeout=90s
   ```

   Back in the first terminal you should see spans printed by the gateway — they
   entered at the agent and were forwarded. You will also see `hostmetrics` (node
   CPU, memory, load) arriving continuously from the agent.

7. **Read the config.** Print the merged config the gateway is actually running and
   find the three pipeline stages:

   ```bash
   kubectl get cm -l app.kubernetes.io/instance=otel-gateway \
     -o jsonpath='{.items[0].data.relay}'
   ```

   Locate `receivers`, `processors` (note `memory_limiter` first, `batch`), and
   `exporters`. This is the receive → process → export shape from the lesson.

8. **Prove the decoupling (thought step).** Open
   [`gateway-values.yaml`](./gateway-values.yaml). To send traces to Tempo instead of
   the console, you would add an `otlp` exporter pointing at Tempo and list it in the
   traces pipeline — **no application change**. You will do exactly that in
   [Module 11.5](../../05-distributed-tracing-with-tempo/).

## Expected result

`kubectl get daemonset,deploy` shows a one-Pod-per-node `otel-agent` DaemonSet and an
`otel-gateway` Deployment. After the `telemetrygen` Job completes, the gateway logs
print the generated spans plus a steady stream of node `hostmetrics` — proving the
app → agent → gateway → exporter pipeline works and that routing lives entirely in
Collector config.

## Cleanup

> Always tear down the cluster so it does not hold resources. Never skip this.

```bash
helm uninstall otel-agent --ignore-not-found
helm uninstall otel-gateway --ignore-not-found
kind delete cluster --name pe-otel
```

## Reflection

- The agent is a DaemonSet and the gateway is a Deployment. Why those two controller
  types for those two roles (hint: node-local collection vs horizontal scaling and
  tail sampling)?
- You changed *where telemetry goes* without touching any application. What does that
  decoupling let a platform team do that per-app vendor SDKs would not?
- `memory_limiter` appears first in the processor list. What happens to **every**
  tenant's telemetry if the shared gateway OOMs, and how does that processor help?

## Stretch goals (optional)

- Add a `batch` size change and an `attributes` processor to
  [`gateway-values.yaml`](./gateway-values.yaml) that stamps every span with
  `deployment.environment: lab`, re-run `helm upgrade`, and confirm the attribute in
  the debug output.
- Also send **metrics** from `telemetrygen` (`metrics --otlp-insecure ...`) and watch
  them flow through the same gateway.
- Read [`app.go`](./app.go) and identify which spans would come from
  *auto*-instrumentation (the HTTP handler) and which are *manual* (the
  `charge-card` business span).
