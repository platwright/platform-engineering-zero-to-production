# Lab — Service discovery with DNS

> You'll deploy a backend behind a ClusterIP Service and a frontend that reaches it
> purely by DNS name, watch EndpointSlices track Pods as you scale, and see readiness
> gating pull an unhealthy Pod out of the rotation. Local kind cluster only — no
> cloud cost.

**Estimated time:** ~40–55 minutes
**Type:** Build
**Deliverable:** A frontend Pod that resolves and calls `backend` by name, plus notes
on how EndpointSlice membership changed as you scaled and broke Pods.

## Objectives

- Reach a set of Pods through a stable Service name instead of Pod IPs.
- Observe EndpointSlices updating as Pods scale and change readiness.
- Resolve a Service by its short name and its fully-qualified DNS name.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter manifests here: [`backend-deployment.yaml`](./backend-deployment.yaml),
  [`backend-service.yaml`](./backend-service.yaml), and
  [`frontend-deployment.yaml`](./frontend-deployment.yaml).

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-networking
   ```

2. **Deploy the backend and its Service.** The backend is `traefik/whoami`, which
   reports which Pod answered and serves a `/health` endpoint:

   ```bash
   kubectl apply -f backend-deployment.yaml
   kubectl apply -f backend-service.yaml
   kubectl rollout status deployment/backend
   ```

3. **Inspect the Service and its endpoints.** The Service has a stable ClusterIP; the
   EndpointSlice lists the current ready Pod IPs:

   ```bash
   kubectl get svc backend -o wide
   kubectl get endpointslices -l kubernetes.io/service-name=backend -o wide
   ```

   You should see three Pod IPs. If you see **none**, the selector and Pod labels
   don't match — that's the classic unreachable-Service bug.

4. **Deploy the frontend and discover the backend by name.** Exec into the frontend
   and resolve + call the Service:

   ```bash
   kubectl apply -f frontend-deployment.yaml
   kubectl rollout status deployment/frontend

   kubectl exec deploy/frontend -- nslookup backend
   kubectl exec deploy/frontend -- curl -s backend/health && echo " <- 200 OK"
   ```

   The short name `backend` resolved because the frontend is in the same namespace.

5. **Prove load balancing across Pods.** Call the Service several times; `whoami`
   prints its Pod hostname, so you'll see different Pods answer:

   ```bash
   kubectl exec deploy/frontend -- sh -c \
     'for i in $(seq 1 6); do curl -s backend | grep Hostname; done'
   ```

6. **Watch EndpointSlices follow scaling.** Scale the backend and re-read the
   endpoints — the Service IP and name never change, but the membership does:

   ```bash
   kubectl scale deployment backend --replicas=5
   kubectl rollout status deployment/backend
   kubectl get endpointslices -l kubernetes.io/service-name=backend -o wide
   ```

7. **See readiness gating remove Pods.** Break the readiness probe by pointing it at
   a path that returns 404, then confirm the Pods leave the EndpointSlice:

   ```bash
   kubectl patch deployment backend --type=json \
     -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/does-not-exist"}]'
   sleep 15
   kubectl get pods -l app=backend          # READY column shows 0/1
   kubectl get endpointslices -l kubernetes.io/service-name=backend -o wide
   ```

   As Pods fail readiness they drop out of the EndpointSlice — Kubernetes stops
   routing to them automatically, with no change to the Service. Restore the good
   probe:

   ```bash
   kubectl patch deployment backend --type=json \
     -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/health"}]'
   kubectl rollout status deployment/backend
   ```

8. **Resolve the fully-qualified name.** Confirm the full DNS form works too:

   ```bash
   kubectl exec deploy/frontend -- nslookup backend.default.svc.cluster.local
   ```

## Expected result

The frontend reached the backend by the name `backend` with no knowledge of Pod IPs;
the EndpointSlice tracked Pods automatically as you scaled from 3 → 5; and breaking
readiness pulled Pods out of the rotation. You've seen stable indirection and
readiness gating in action.

## Cleanup

> Tear the cluster down so it stops holding memory. Never skip this.

```bash
kubectl delete -f frontend-deployment.yaml --ignore-not-found
kubectl delete -f backend-service.yaml --ignore-not-found
kubectl delete -f backend-deployment.yaml --ignore-not-found
kind delete cluster --name pe-networking
```

## Reflection

- The Service's ClusterIP never changed while the Pods behind it did. Why is that
  indirection the whole point of a Service?
- When you broke readiness, you didn't touch the Service at all, yet traffic stopped
  going to the bad Pod. Which object changed, and who changed it?
- What single YAML mistake would make a healthy backend completely unreachable with
  no error message?

## Stretch goals (optional)

- Reach the Service from your laptop with
  `kubectl port-forward svc/backend 8080:80`, then `curl localhost:8080/health`.
- Create a second namespace, run a client Pod there, and confirm `backend` does
  **not** resolve but `backend.default` does.
- Convert `backend-service.yaml` to a headless Service (`clusterIP: None`) and
  observe that DNS now returns individual Pod IPs instead of one virtual IP.
