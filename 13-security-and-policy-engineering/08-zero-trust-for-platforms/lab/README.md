# Lab — L7 zero-trust authorization with Cilium

> You'll build a Cilium-enabled cluster, deploy a `frontend` and `backend`, and write a
> `CiliumNetworkPolicy` that authorizes **only** `frontend → backend GET /api/*`. Then
> you'll prove zero trust at L7: an allowed caller on a forbidden path (`/admin`) is
> still denied, and an unknown caller is denied entirely.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** A working L7 authorization policy plus evidence that allowed and
forbidden calls are treated differently by *identity and path*, not by IP.

## Objectives

- Stand up a local cluster with Cilium as the CNI.
- Observe default-allow intra-cluster traffic, then lock it down.
- Author an identity-based **L7** `CiliumNetworkPolicy`.
- Prove least-privilege traffic: right caller + right path = allow; anything else = deny.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- The [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/)
  (used to install Cilium and, optionally, Hubble).
- Starter files here: [`kind-cilium.yaml`](./kind-cilium.yaml),
  [`apps.yaml`](./apps.yaml), [`default-deny.yaml`](./default-deny.yaml),
  [`ciliumnetworkpolicy-l7.yaml`](./ciliumnetworkpolicy-l7.yaml), and the design
  worksheet [`jit-access-design.md`](./jit-access-design.md).

> **Cilium is required for the L7 part.** Plain Kubernetes `NetworkPolicy` is L3/L4 only
> and cannot match an HTTP method/path. If you cannot run Cilium, read the policy files
> and complete `jit-access-design.md` as a design exercise — the concepts still land.

## Steps

1. **Create a cluster with the default CNI disabled, then install Cilium.**

   ```bash
   kind create cluster --name pe-zt --config kind-cilium.yaml
   cilium install
   cilium status --wait
   ```

   `kind-cilium.yaml` disables kindnet so Cilium can own the dataplane (and L7 proxy).

2. **Deploy the demo apps.** A `frontend` (a curl pod) and a `backend` (`traefik/whoami`,
   which returns `200` and echoes the path on every route):

   ```bash
   kubectl apply -f apps.yaml
   kubectl -n zt-demo rollout status deploy/backend
   kubectl -n zt-demo get pods -o wide
   ```

3. **Baseline: everything is allowed (implicit trust).** Before any policy, `frontend`
   can hit *any* path on `backend`:

   ```bash
   FE=$(kubectl -n zt-demo get pod -l app=frontend -o name)
   kubectl -n zt-demo exec "$FE" -- curl -s -o /dev/null -w "api  -> %{http_code}\n" http://backend/api/health
   kubectl -n zt-demo exec "$FE" -- curl -s -o /dev/null -w "admin-> %{http_code}\n" http://backend/admin
   ```

   Both return `200`. Nothing checked *who* called or *what* they asked for.

4. **(Optional) Apply default-deny first.** This makes the zero-trust default explicit —
   all ingress to the namespace's pods is denied until a policy allows it:

   ```bash
   kubectl apply -f default-deny.yaml
   kubectl -n zt-demo exec "$FE" -- curl -s -m 5 -o /dev/null -w "api  -> %{http_code}\n" http://backend/api/health || echo "denied (timeout)"
   ```

   Now even `/api/health` is blocked — we've removed implicit trust. Next we allow back
   exactly one thing.

5. **Apply the L7 authorization policy.** Allow only `frontend → backend` `GET /api/*`:

   ```bash
   kubectl apply -f ciliumnetworkpolicy-l7.yaml
   kubectl -n zt-demo get ciliumnetworkpolicy
   ```

6. **Prove L7 least privilege.** Same caller, two paths — only the authorized one works:

   ```bash
   kubectl -n zt-demo exec "$FE" -- curl -s -o /dev/null -w "GET /api/health -> %{http_code}\n" http://backend/api/health
   kubectl -n zt-demo exec "$FE" -- curl -s -o /dev/null -w "GET /admin      -> %{http_code}\n" http://backend/admin
   ```

   `GET /api/health` returns `200`; `GET /admin` returns `403` — denied by Cilium's L7
   proxy *before* it reaches the backend. The allow is scoped to a method and path, not
   just a port.

7. **Prove identity matters.** Run a pod that is *not* `frontend` and confirm it's denied
   even on the allowed path — identity, not network location, is the gate:

   ```bash
   kubectl -n zt-demo run intruder --image=curlimages/curl:8.11.1 --restart=Never -- sleep 600
   kubectl -n zt-demo exec intruder -- curl -s -m 5 -o /dev/null -w "intruder /api -> %{http_code}\n" http://backend/api/health || echo "denied"
   ```

8. **(Optional) Watch the decisions with Hubble.**

   ```bash
   cilium hubble enable
   hubble observe --namespace zt-demo --follow
   ```

## Expected result

With the L7 policy applied:

- `frontend` `GET /api/health` → **200** (allowed).
- `frontend` `GET /admin` → **403** (denied at L7, right caller, wrong path).
- `intruder` `GET /api/health` → **denied** (wrong identity).

You've enforced least privilege on *traffic* — authorized by workload identity and HTTP
path, exactly the zero-trust ideal.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
kubectl delete -f ciliumnetworkpolicy-l7.yaml -f default-deny.yaml -f apps.yaml --ignore-not-found
kubectl -n zt-demo delete pod intruder --ignore-not-found
kind delete cluster --name pe-zt
```

## Reflection

- The policy selects pods by **label** (`app=frontend`), not IP. Why does that survive
  pod rescheduling and scaling when an IP allowlist would not?
- You denied `/admin` while allowing `/api/*` for the *same* caller. What class of
  attack does path-level authorization stop that a port-level rule cannot?
- Fill in [`jit-access-design.md`](./jit-access-design.md): how would you give a human the
  equivalent of this least-privilege, time-boxed access — without anyone holding standing
  cluster-admin?

## Stretch goals (optional)

- Tighten the policy to a specific `GET` path regex (e.g. `/api/v1/.*`) and confirm other
  `/api` paths are denied.
- Add an egress L7 rule so `frontend` may only reach `backend` and the cluster DNS, and
  nothing else.
- Enable Hubble UI and screenshot the allowed-vs-denied flows as audit evidence.
- Explore Cilium [mutual authentication](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication/)
  to add mTLS identity on top of the L7 policy.
