# Module 14.5 — Kubernetes Gateway API

> How does external traffic get *into* the cluster, safely, when the platform team owns
> the entry point but app teams own their own routes? The old **Ingress** API muddled
> those roles and bolted vendor features onto annotations. The **Gateway API** — its
> official successor — fixes this with clean **role separation**: the platform owns the
> `Gateway`, developers own their `HTTPRoute`s, and richer routing (traffic splitting,
> header matching) is first-class, not an annotation hack.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 14.1](../01-kubernetes-networking-fundamentals/),
[Module 03.3 · Services and Networking](../../03-kubernetes-fundamentals/03-services-and-networking/),
Docker, and [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain why the Gateway API replaces Ingress, and the problems it solves.
- Describe the **role-separated** resources: GatewayClass, Gateway, HTTPRoute.
- Write an **HTTPRoute** with path/header matching and **weighted traffic splitting**.
- Explain how the Gateway API enables safe **multi-tenant** ingress.
- Name reference implementations and where TLS is terminated.

---

## 1. Concept

### Why Ingress wasn't enough

The original **Ingress** API was a single resource that tried to be everything: it
described host/path routing, but anything beyond basic HTTP (TLS options, traffic
splitting, header rules, timeouts) was shoved into **controller-specific
annotations**. The results were painful:

- **No portability** — an nginx-ingress annotation means nothing to GKE's controller.
  Switching ingress controllers meant rewriting everything.
- **No role separation** — one Ingress object mixed concerns the *platform* owns (the
  load balancer, TLS certs, the public entry point) with concerns *developers* own
  (which path routes to my service). Everyone edited the same resource.
- **Limited expressiveness** — canary splits, header-based routing, and non-HTTP
  protocols were awkward or impossible in standard Ingress.

### The Gateway API: roles as resources

The **Gateway API** (the official Kubernetes successor to Ingress) redesigns ingress
around **who owns what**. It splits one monolith into a layered set of resources, each
owned by a different role:

```text
   ROLE                 RESOURCE          OWNS
   ────                 ────────          ────
   Infrastructure  →    GatewayClass      what KIND of gateway exists (the impl),
   provider                               e.g. "gke-l7-global" or "cilium"

   Platform team   →    Gateway           the actual entry point: ports, listeners,
                                          hostnames, TLS certs. One shared front door.

   Developer team  →    HTTPRoute         "route /api/my-app to my Service" — in the
                                          TEAM's own namespace, no platform ticket.
```

This is the IDP **role separation** made concrete at the network layer: the platform
team runs the Gateway (the load balancer, the TLS, the public IP) as a service;
developers attach their own `HTTPRoute`s to it from their namespaces, self-service,
without touching shared infrastructure. It's the networking expression of the
golden-path, X-as-a-Service model from Phase 1.

### HTTPRoute: expressive, developer-owned routing

An `HTTPRoute` attaches to a `Gateway` (via `parentRefs`) and declares how matching
requests reach backends. It natively supports what Ingress couldn't:

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: team-a
spec:
  parentRefs:
    - name: platform-gateway
      namespace: platform-system
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api/my-app
      backendRefs:
        - name: my-app
          port: 8080
```

- **Path and header matching** — route by path prefix, exact path, method, or headers.
- **Weighted traffic splitting** — send 90% to `v1` and 10% to `v2` for a **canary**,
  just by setting `weight` on multiple `backendRefs`. This is progressive delivery
  without a mesh.
- **Cross-namespace with guardrails** — a Gateway can allow routes only from specific
  namespaces (via `allowedRoutes`), so the platform controls who may attach.

### Traffic splitting for canary releases

Weighted `backendRefs` make canary deployments a native, declarative operation:

```yaml
  rules:
    - backendRefs:
        - name: my-app-v1
          port: 8080
          weight: 90
        - name: my-app-v2
          port: 8080
          weight: 10
```

Ninety percent of traffic goes to v1, ten percent to the new v2 — shift the weights to
roll forward, or zero out v2 to roll back. (Full automated progressive delivery adds
Argo Rollouts/Flagger — GitOps maturity Level 4 from Module 08.6 — but the *mechanism*
is right here in the Gateway API.)

### TLS, protocols, and implementations

- **TLS** — the Gateway terminates TLS at its listeners (or passes it through for
  end-to-end encryption). Certs are a platform concern, configured once on the Gateway.
- **Beyond HTTP** — `TCPRoute` and `TLSRoute` handle non-HTTP traffic.
- **Reference implementations** — the API is a spec; a controller implements it:
  **GKE Gateway**, **Cilium Gateway**, **Envoy Gateway**, **Istio**, NGINX Gateway
  Fabric, and others. You write portable Gateway/HTTPRoute resources; the controller
  realizes them. Switching implementations no longer means rewriting annotations.

---

## 2. Why it matters for platform engineering

Ingress is where "the platform owns the front door, teams own their routes" either
works or turns into a ticket queue. The Gateway API makes the good version structural:

- **Self-service ingress.** Developers publish routes from their own namespaces without
  a platform ticket — the exact friction reduction Phase 1 is about — while the
  platform keeps control of the shared Gateway, TLS, and which namespaces may attach.
- **Portability.** Gateway/HTTPRoute are standard resources; you can change the
  underlying controller (even move clouds) without rewriting every team's routing.
- **Progressive delivery built in.** Weighted splits give canary releases natively,
  reducing deploy risk across every team.
- **Clean multi-tenancy.** `allowedRoutes` and namespaced HTTPRoutes enforce who can
  expose what — a governance control the old Ingress lacked.

## 3. Mental model

```text
   Internet
      │
      ▼
   Gateway (platform-system)          ← PLATFORM owns: LB, port 443, TLS, who may attach
      │   listeners, certs
      ├── HTTPRoute (team-a)           ← DEVELOPERS own: /api/my-app -> their Service
      │      path/header match, weighted canary (90/10)
      └── HTTPRoute (team-b)           ← each team, in its own namespace, self-service

   GatewayClass  ← the IMPLEMENTATION (GKE / Cilium / Envoy) behind it all

   One front door, many self-service routes, portable across controllers.
```

One sentence: **the Gateway API splits ingress by role — platform owns the Gateway,
developers own their HTTPRoutes — with native path/header matching and weighted canary
splits, portable across implementations.**

## 4. Minimal implementation

The smallest demonstration needs a Gateway controller, a Gateway, and one HTTPRoute.
On a local cluster you install a controller (the lab uses NGINX Gateway Fabric or
Envoy Gateway), then:

```bash
# Platform team: one shared Gateway (the front door)
kubectl apply -f gateway.yaml

# Developer team: attach a route from their own namespace
kubectl apply -f httproute.yaml

# Reach the service through the Gateway
curl -H "Host: demo.example.com" http://<gateway-address>/
```

Two resources, two owners, one front door. The lab extends this to a **90/10 canary
split** between two versions — watching requests distribute across them — which is the
capability that most clearly separates the Gateway API from Ingress.

## 5. Hands-on lab

Install a Gateway controller on a local cluster, stand up a shared **Gateway**
(platform-owned), attach **HTTPRoutes** from an app namespace, and configure a **90/10
weighted canary split** between two versions — watching traffic distribute.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **The Gateway is the public front door — treat it as tier-1.** Its availability, TLS
  certs, and capacity affect every exposed service. Give it SLOs and monitoring.
- **Govern who may attach.** Use `allowedRoutes` (by namespace label) so only sanctioned
  teams expose services through the shared Gateway; pair with policy (Kyverno).
- **Automate TLS.** Integrate cert-manager (or the cloud's managed certs) so certificate
  issuance/rotation isn't a manual, expiry-prone task.
- **Pick the implementation deliberately.** GKE Gateway (managed), Cilium Gateway
  (unifies with your CNI — Module 14.4), Envoy Gateway (portable). Capabilities and
  operational models differ.
- **Plan the Ingress → Gateway migration.** Many clusters still run Ingress; migrating
  is a real project. Run both during transition and move teams incrementally.
- **Weighted splits are a mechanism, not full progressive delivery.** For automated,
  metric-driven rollouts add Argo Rollouts/Flagger (Module 08.6).

## 7. Common mistakes

- **Recreating the Ingress monolith.** — Having the platform team hand-edit every team's
  routes defeats the point. *Fix:* let teams own HTTPRoutes in their namespaces; govern
  with `allowedRoutes`.
- **No namespace governance on attachment.** — Any namespace attaching to the shared
  Gateway is a security gap. *Fix:* restrict `allowedRoutes`.
- **Manual TLS.** — Certs expire and cause outages. *Fix:* automate with cert-manager/
  managed certs.
- **Assuming all implementations are equal.** — Feature and behavior gaps between GKE/
  Cilium/Envoy gateways. *Fix:* validate your required features on the chosen
  controller.
- **Treating weighted split as safe-by-itself.** — A canary with no metrics is just
  slower breakage. *Fix:* watch error rate/latency on the new version (Project 3) and
  automate rollback.

## 8. Assessment

**Knowledge checks**

1. Name the three core Gateway API resources and which role owns each.
2. What problem with Ingress annotations does the Gateway API solve?
3. How do you express a 90/10 canary split in an HTTPRoute?
4. How does the platform control which namespaces may attach routes to a shared
   Gateway?
5. Where is TLS typically terminated in a Gateway API setup?

**Concept exercise**

> Explain how the Gateway API lets developers publish their own external routes without
> the platform team becoming a bottleneck — **without using the words "Gateway" or
> "HTTPRoute."** Describe it in terms of ownership.

**Design exercise**

> A platform serves 30 teams, each needing to expose HTTP services on the company
> domain, with TLS, and the ability to canary new versions. Sketch how you'd use the
> Gateway API: what the platform team owns, what teams own, and how you'd keep it safe.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** GatewayClass (infrastructure provider — the implementation), Gateway
  (platform team — the entry point/LB/TLS), HTTPRoute (developer team — routing rules).
- **Q2:** Ingress crammed everything into controller-specific annotations
  (non-portable, limited); the Gateway API makes routing, splitting, and roles
  first-class, portable resources.
- **Q3:** Multiple `backendRefs` with `weight` values (e.g. v1 weight 90, v2 weight 10)
  in one rule.
- **Q4:** The Gateway's `allowedRoutes` restricts which namespaces (by label) may attach
  routes.
- **Q5:** At the Gateway's listeners (terminate there, or pass through for end-to-end
  TLS) — a platform-owned concern configured once on the Gateway.
- **Design:** Platform team owns one (or a few) shared Gateway(s) in `platform-system`
  with TLS (cert-manager) and `allowedRoutes` limited to team namespaces; each team
  owns HTTPRoutes in its namespace for its paths, using weighted backendRefs to canary;
  governance via Kyverno + `allowedRoutes`, and observability on the Gateway and each
  service (Project 3).

</details>

## 9. Further reading

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/) and [API concepts](https://gateway-api.sigs.k8s.io/concepts/api-overview/)
- [Gateway API — traffic splitting](https://gateway-api.sigs.k8s.io/guides/traffic-splitting/)
- [GKE Gateway controller](https://cloud.google.com/kubernetes-engine/docs/concepts/gateway-api) · [Cilium Gateway API](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/) · [Envoy Gateway](https://gateway.envoyproxy.io/)
- [Ingress vs Gateway API — migration](https://gateway-api.sigs.k8s.io/guides/migrating-from-ingress/)
- [cert-manager](https://cert-manager.io/) for automated TLS

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [14.4 — Cilium and eBPF](../04-cilium-and-ebpf/) · _Next:_ [14.6 — Service Mesh Reference →](../06-service-mesh-reference/)
