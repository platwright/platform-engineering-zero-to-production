# Module 03.3 — Services and Networking

> Pods are mortal and their IP addresses change every time they're rescheduled. So
> how does one Pod reliably reach another? The answer is the **Service** — a stable
> name and virtual IP in front of a changing set of Pods — plus cluster **DNS**.
> This module explains service discovery from first principles, then the four Service
> types and when to use each.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 03.2](../02-workloads/) and a working `kubectl` +
[kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain why Pod IPs are unreliable and how a **Service** provides a stable
  endpoint.
- Describe how a Service tracks its Pods via **label selectors** and
  **EndpointSlices**.
- Choose between **ClusterIP, NodePort, LoadBalancer, headless, and ExternalName**
  Services.
- Resolve a Service by its DNS name
  (`service.namespace.svc.cluster.local`) and reason about cross-namespace access.
- Explain at a high level how **kube-proxy** turns a virtual IP into real traffic.

---

## 1. Concept

### The problem: Pods are moving targets

Every Pod gets its own IP, but that IP is **ephemeral**. Roll out a new version,
reschedule onto another node, scale up or down — the Pods (and their IPs) change
constantly. If your frontend hard-coded a backend Pod's IP, it would break on the
next deploy. You need a **stable indirection** between "the name of a thing I want to
talk to" and "the current set of Pods that provide it."

### The Service: a stable front door

A **Service** is that indirection. It gives a logical set of Pods:

- a **stable virtual IP** (the ClusterIP) that never changes for the life of the
  Service, and
- a **stable DNS name**,

and it **load-balances** connections across whichever Pods currently match. The
Service finds its Pods with a **label selector** — "all Pods with `app: backend`" —
not a fixed list. As Pods come and go, the membership updates automatically.

### How a Service tracks its Pods: EndpointSlices

A controller watches for Pods that match the Service's selector *and* are **ready**
(passing their readiness probe) and records their IPs. Historically this was one
`Endpoints` object; modern clusters use **EndpointSlices** (shardable, scalable
chunks of endpoints). The chain:

```text
Service (selector: app=backend, stable ClusterIP 10.96.0.42)
   └── EndpointSlice  ← controller keeps this in sync with READY matching Pods
          └── [ 10.244.1.5:80 , 10.244.2.7:80 , … ]  ← current Pod IPs
```

This is why **readiness probes matter** ([Module 03.8](../08-health-and-scheduling/)):
a Pod that isn't ready is removed from the EndpointSlice, so the Service stops
sending it traffic without you doing anything.

### Cluster DNS

Kubernetes runs an in-cluster DNS server (**CoreDNS**). Every Service gets an `A`
record at:

```text
<service>.<namespace>.svc.cluster.local
```

From a Pod in the *same* namespace, the short name `backend` resolves. From another
namespace you need `backend.<namespace>` or the full name. This DNS-based discovery
is the normal way services talk to each other — never hard-code IPs.

### The four Service types

- **ClusterIP** (default) — a virtual IP reachable **only inside the cluster**. This
  is how services talk to each other. 90% of your Services are ClusterIP.
- **NodePort** — opens the same high port (30000–32767) on **every node**, forwarding
  to the Service. Lets you reach the Service from outside using
  `nodeIP:nodePort`. Blunt and mostly used for local testing or under a
  LoadBalancer.
- **LoadBalancer** — asks the **cloud provider** to provision an external load
  balancer with a public IP pointing at the Service. This is how you expose an app
  to the internet on GKE/EKS/AKS. On a bare kind cluster there's no cloud, so it
  stays `<pending>` unless you add a controller like MetalLB.
- **ExternalName** — no proxying at all; it's a DNS `CNAME` to an external hostname
  (e.g. `db.example.com`). Lets in-cluster clients use a stable internal name for an
  external dependency.

### Headless Services

Set `clusterIP: None` and the Service becomes **headless**: no virtual IP, no load
balancing. Instead, DNS returns the **individual Pod IPs** directly. This is what
StatefulSets use ([Module 03.2](../02-workloads/)) so each Pod is addressable by its
stable name (`web-0.web.default.svc.cluster.local`). Use it when the client needs to
reach *specific* Pods, not "any one of them."

### kube-proxy: making the virtual IP real

The ClusterIP is virtual — no single machine owns it. **kube-proxy**, running on
every node, programs the kernel so that traffic to the ClusterIP is transparently
redirected to a real Pod IP. Common modes:

- **iptables** (default) — kube-proxy writes iptables rules; the kernel picks a
  backend randomly. Simple and solid for most clusters.
- **IPVS** — uses the kernel's load balancer; scales to many Services with more
  balancing algorithms.
- **eBPF** (e.g. **Cilium**) — replaces kube-proxy with eBPF programs for lower
  latency and richer policy at scale.

You rarely configure this directly, but knowing it exists explains *how* a packet to
a made-up IP reaches a real container ([Phase 14](../../14-kubernetes-networking/)).

---

## 2. Why it matters for platform engineering

- **Service discovery is the backbone of microservices.** Teams rely on "call
  `backend` and it works" without knowing where Pods run. The platform provides that
  guarantee; you need to understand how it's delivered to debug it.
- **Readiness gating is a reliability feature you give teams for free.** Because
  Services only route to ready Pods, a correct readiness probe means deploys and
  crashes don't send traffic into the void. Teach teams to wire it up.
- **Exposure is a security and cost decision.** Every `LoadBalancer` is a public IP
  and a cloud bill. Platforms usually funnel external traffic through a shared
  **Ingress/Gateway** ([Phase 14](../../14-kubernetes-networking/)) instead of a
  LoadBalancer per service — fewer IPs, central TLS, one place for policy.
- **DNS failures look like app failures.** A huge share of "the service is down"
  incidents are actually DNS or selector mismatches. Knowing the Service →
  EndpointSlice → Pod chain is how you find the real cause fast.

---

## 3. Mental model

A Service is a **stable sign on a building** whose tenants keep changing. Clients use
the sign (name/IP); the directory (EndpointSlice) is kept current with whoever is
actually ready inside.

```text
   client Pod
      │  "connect to  backend  (or 10.96.0.42)"
      ▼
   ┌─────────────────────────────────────────────┐
   │ Service "backend"  (stable name + ClusterIP) │   selector: app=backend
   └───────────────────────┬─────────────────────┘
                           │ kube-proxy redirects to a READY endpoint
            ┌──────────────┼──────────────┐
            ▼              ▼              ▼
        Pod app=backend  Pod app=backend  Pod app=backend
        (ready)          (ready)          (NOT ready → excluded)

   DNS: backend.default.svc.cluster.local  →  10.96.0.42 (the ClusterIP)
```

Rules to remember:

1. **Never talk to Pod IPs; talk to Service names.** Pods are moving targets.
2. **Readiness decides membership.** Not-ready Pods silently leave the rotation.
3. **ClusterIP for inside, LoadBalancer/Ingress for outside, headless for specific
   Pods.**

---

## 4. Minimal implementation

First, *feel the problem*. A bare Pod's IP is not something you can depend on:

```bash
kubectl run backend --image=traefik/whoami
kubectl get pod backend -o jsonpath='{.status.podIP}{"\n"}'   # note this IP
kubectl delete pod backend; kubectl run backend --image=traefik/whoami
kubectl get pod backend -o jsonpath='{.status.podIP}{"\n"}'   # DIFFERENT IP
```

Now put a **stable Service** in front of a set of Pods and reach them by name:

```bash
kubectl create deployment backend --image=traefik/whoami --replicas=3
kubectl expose deployment backend --port=80            # creates a ClusterIP Service
kubectl get svc backend -o wide                        # a stable ClusterIP + selector
kubectl get endpointslices -l kubernetes.io/service-name=backend   # the 3 Pod IPs
```

Resolve and call it by DNS from another Pod — the name is stable even as Pods change:

```bash
kubectl run client --image=nicolaka/netshoot --restart=Never -it --rm -- \
  sh -c 'nslookup backend && curl -s backend/health && echo OK'
```

Scale the backend and watch the EndpointSlice membership update with **no change to
the client's code or the Service's IP**:

```bash
kubectl scale deployment backend --replicas=5
kubectl get endpointslices -l kubernetes.io/service-name=backend
```

The indirection held: the name and IP stayed constant while the Pods behind them
changed.

---

## 5. Hands-on lab

You'll deploy a backend behind a ClusterIP Service and a frontend that discovers it
purely by DNS name, watch EndpointSlices track Pods as you scale, and see readiness
gating remove an unhealthy Pod from the rotation — all on a local kind cluster.

➡️ **[Start the lab: Service discovery with DNS](./lab/README.md)**

---

## 6. Production considerations

- **Don't expose every service with a LoadBalancer.** Each one is a public IP and a
  recurring cloud cost. Use a shared **Ingress or Gateway** controller for HTTP, with
  central TLS and routing ([Phase 14](../../14-kubernetes-networking/)); reserve
  `LoadBalancer` for the ingress itself or non-HTTP protocols.
- **Readiness probes are non-negotiable for traffic correctness.** Without them a
  Service routes to Pods that aren't ready to serve. With them, rollouts and crashes
  are invisible to callers.
- **Mind DNS performance and caching.** Chatty services doing per-request lookups can
  hammer CoreDNS; tune `ndots`, enable NodeLocal DNSCache, and watch CoreDNS metrics
  at scale.
- **Network traffic is open by default.** By default *any* Pod can reach *any*
  Service. Production clusters add **NetworkPolicies** to restrict who can talk to
  whom ([Phase 13](../../13-security-and-policy-engineering/)).
- **Prefer topology-aware routing for cost/latency** in multi-zone clusters so
  traffic stays in-zone where possible, reducing cross-zone data charges.

---

## 7. Common mistakes

- **Hard-coding Pod IPs (or NodePorts) between services.** — They change on every
  reschedule. *Fix:* always use the Service DNS name; let the Service and
  EndpointSlice track Pods.
- **Selector/label mismatch.** — The Service's selector doesn't match the Pods'
  labels, so the EndpointSlice is empty and nothing is reachable — with no error.
  *Fix:* `kubectl get endpointslices` should list Pod IPs; if empty, the selector is
  wrong. (This is the Module 03.9 "unreachable Service" bug.)
- **No readiness probe, so traffic hits unready Pods.** — Requests fail during
  startup or after a crash. *Fix:* add a readiness probe; Kubernetes gates endpoint
  membership on it.
- **A `LoadBalancer` per microservice.** — Dozens of public IPs and a surprise cloud
  bill. *Fix:* one shared Ingress/Gateway; ClusterIP for everything behind it.
- **Forgetting the namespace in cross-namespace calls.** — `backend` resolves only in
  the same namespace. *Fix:* use `backend.<namespace>` (or the FQDN) across
  namespaces.

---

## 8. Assessment

**Knowledge checks**

1. Why can't one Pod reliably use another Pod's IP address directly?
2. How does a Service know which Pods to send traffic to, and what role does the
   readiness probe play?
3. Name the four Service types and give one use case for each.
4. What is a headless Service, and which workload type depends on it?
5. What DNS name resolves a Service named `payments` in namespace `prod`?

**Concept exercise**

> Explain how a frontend reliably reaches a backend that is constantly being
> rescheduled — **without using the words "Service," "DNS," or "kube-proxy."**
> Describe the stable-indirection idea in your own terms.

**Debugging / trade-off exercise**

> A team reports "the backend is unreachable" but the backend Pods are `Running` and
> healthy. `kubectl get endpointslices` for the Service shows **no endpoints**. Walk
> through what's almost certainly wrong and how you'd confirm it.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Pod IPs are ephemeral — reschedules, scaling, and deploys change them — so
  any hard-coded IP breaks. You need a stable indirection.
- **Q2:** By a label selector; a controller keeps an EndpointSlice of the matching
  **ready** Pods' IPs. Not-ready Pods are excluded, so readiness decides who receives
  traffic.
- **Q3:** ClusterIP (internal service-to-service), NodePort (reach via a port on each
  node, local testing), LoadBalancer (external public IP via the cloud), ExternalName
  (CNAME to an external host).
- **Q4:** `clusterIP: None`; DNS returns individual Pod IPs instead of one virtual
  IP. StatefulSets depend on it for per-Pod stable addresses.
- **Q5:** `payments.prod.svc.cluster.local`.
- **Debugging exercise:** An empty EndpointSlice with healthy Pods means the
  Service's **selector doesn't match the Pods' labels** (or the Pods aren't passing
  readiness). Confirm with `kubectl get pods --show-labels` and compare to
  `kubectl get svc <name> -o jsonpath='{.spec.selector}'`; fix the selector or labels
  so they agree, and verify readiness.

</details>

---

## 9. Further reading

- Kubernetes — [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
- Kubernetes — [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- Kubernetes — [EndpointSlices](https://kubernetes.io/docs/concepts/services-networking/endpoint-slices/)
- Kubernetes — [Virtual IPs and Service proxies (kube-proxy)](https://kubernetes.io/docs/reference/networking/virtual-ips/)
- Kubernetes — [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.2 — Workloads](../02-workloads/)
· _Next:_ [Module 03.4 — Configuration →](../04-configuration/)
