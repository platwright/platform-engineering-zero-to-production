# Lab — A shared Gateway with a canary HTTPRoute

> You'll stand up a platform-owned **Gateway**, attach a developer-owned **HTTPRoute**
> from an app namespace, and configure a **90/10 canary split** between two versions —
> then watch traffic distribute and shift the weights to "promote" the new version.
> This is role-separated, self-service ingress with progressive delivery built in. All
> local and free.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** Requests through the Gateway landing ~90% on v1 and ~10% on v2, and a
weight change that flips the ratio — all without editing shared infrastructure.

## Objectives

- Install a Gateway API controller and the Gateway API CRDs.
- Create a platform-owned Gateway with namespace-restricted attachment.
- Attach a developer HTTPRoute and observe a weighted canary split.

## Prerequisites

- Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/). No cost — all local.
- Starter files here: [`gateway.yaml`](./gateway.yaml),
  [`httproute-canary.yaml`](./httproute-canary.yaml).

## Steps

1. **Create a cluster and install the Gateway API CRDs + a controller** (NGINX Gateway
   Fabric):

   ```bash
   kind create cluster --name gw-lab

   # Gateway API CRDs (standard channel)
   kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml

   # NGINX Gateway Fabric (a reference implementation)
   kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.4.0/crds.yaml
   kubectl apply -f https://github.com/nginxinc/nginx-gateway-fabric/releases/download/v1.4.0/nginx-gateway.yaml
   kubectl -n nginx-gateway rollout status deploy/nginx-gateway --timeout=180s
   ```

2. **Create the platform namespace and the shared Gateway** (platform-owned):

   ```bash
   kubectl create namespace platform-system
   kubectl apply -f gateway.yaml
   kubectl -n platform-system get gateway platform-gateway
   ```

3. **Deploy the two app versions and the developer HTTPRoute** (the canary):

   ```bash
   kubectl apply -f httproute-canary.yaml
   kubectl -n team-a wait --for=condition=available deploy --all --timeout=120s
   ```

4. **Reach the app through the Gateway.** Port-forward the controller's service and
   send requests:

   ```bash
   # Find the Gateway's Service (NGINX Gateway Fabric exposes it in nginx-gateway)
   kubectl -n nginx-gateway port-forward svc/nginx-gateway 8080:80 &

   curl -s http://localhost:8080/
   ```

5. **Observe the 90/10 split.** Send many requests and count the versions:

   ```bash
   for i in $(seq 1 50); do curl -s http://localhost:8080/; done | sort | uniq -c
   # ~45 "hello from v1" and ~5 "hello from v2" — the weighted split in action
   ```

6. **Promote the canary** by shifting the weights (the developer edits their own route,
   no platform ticket):

   ```bash
   # Flip to 10/90 (favor v2), then re-test
   kubectl -n team-a patch httproute demo --type=json -p='[
     {"op":"replace","path":"/spec/rules/0/backendRefs/0/weight","value":10},
     {"op":"replace","path":"/spec/rules/0/backendRefs/1/weight","value":90}]'
   for i in $(seq 1 50); do curl -s http://localhost:8080/; done | sort | uniq -c
   # now mostly "hello from v2" — you rolled the canary forward by changing weights
   ```

## Expected result

- The Gateway is `Programmed` and the HTTPRoute is `Accepted`.
- ~90% of requests hit v1 and ~10% hit v2 initially.
- After the weight patch, the ratio flips toward v2 — a promotion with no change to the
  shared Gateway.

## Cleanup

```bash
# stop the port-forward (jobs/kill %1), then:
kind delete cluster --name gw-lab
```

## Reflection

- The platform team never touched `team-a`'s routing, and `team-a` never touched the
  Gateway. How does that split reduce the platform team's ticket load (Phase 1)?
- You canaried by editing weights. What's still missing to make this a *safe* automated
  rollout (hint: metrics + auto-rollback, Modules 08.6 and Project 3)?
- The Gateway restricted attachment to namespaces labelled `gateway-access: true`. Why
  is that governance important on a shared front door?

## Stretch goals (optional)

- Add a second HTTPRoute with **header-based matching** (route `X-Canary: true` requests
  always to v2) alongside the weighted split.
- Install **Cilium Gateway** or **Envoy Gateway** instead and re-apply the *same*
  Gateway/HTTPRoute YAML — proving portability across implementations.
