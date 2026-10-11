# Module 14.1 — Kubernetes Networking Fundamentals

> Kubernetes networking looks like magic until you learn the one rule it's built on:
> **every pod can reach every other pod directly, with no NAT**, as if they were all
> on one big flat network. This module builds the mental model from that rule — veth
> pairs and bridges, the pod-to-pod and pod-to-Service paths, DNS, and what kube-proxy
> actually does — so that when traffic doesn't flow, you know exactly where to look.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Phase 3 · Services and Networking](../../03-kubernetes-fundamentals/03-services-and-networking/),
Docker, and [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- State the Kubernetes networking model and its four core requirements.
- Explain how a packet travels **pod → pod** on the same node and across nodes.
- Explain how a packet travels **pod → Service → pod**, and what rewrites the IP.
- Trace the **DNS resolution** chain for a Service name.
- Describe what **kube-proxy** does (and what replaces it).

---

## 1. Concept

### The one rule: a flat network, no NAT

Kubernetes imposes a deliberately simple networking model. Every implementation (every
CNI) must satisfy four requirements:

```text
1. Every Pod gets its own unique IP address.
2. Pods on a node can reach all Pods on all nodes WITHOUT NAT.
3. Agents on a node (e.g. kubelet) can reach all Pods on that node.
4. A Pod sees its own IP as the same IP others use to reach it (no NAT surprises).
```

The result is a **flat network**: from any pod's point of view, every other pod is
directly reachable at its IP, as if they shared one giant LAN — regardless of which
node they're actually on. No port mapping, no NAT between pods. This is a huge
simplification versus the Docker single-host world (Module 02.3), where you published
ports and containers lived behind the host.

Everything else — Services, DNS, NetworkPolicies, ingress — is built *on top of* this
flat pod network. Hold onto the rule; it explains almost every "why can't X reach Y?"

### Inside a node: veth pairs and a bridge

How does a pod get a network interface that's reachable from the node and from other
nodes? With a **virtual ethernet (veth) pair** — think of it as a virtual cable with
two ends:

```text
        Node's network namespace                 Pod's network namespace
   ┌──────────────────────────────┐        ┌────────────────────────────┐
   │   cni0 (bridge)              │        │   eth0  (10.244.1.5)       │
   │     │                        │        │     │                      │
   │   vethXXXX ◄────── veth pair ─────────────► (other end)            │
   └──────────────────────────────┘        └────────────────────────────┘
```

- One end of the veth pair (`eth0`) lives **inside the pod's network namespace** (the
  isolation primitive from Module 02.1) and holds the pod's IP.
- The other end lives in the **node's** namespace and is plugged into a **bridge**
  (often `cni0`) — a virtual switch connecting all pods on that node.

Two pods on the *same node* talk through the bridge, like two machines on one switch.

### Across nodes: the CNI's job

When a pod on node A talks to a pod on node B, the packet leaves the bridge and must
cross the physical network. Getting it to the right node, with the destination's pod
IP intact (no NAT, per the rule), is the **CNI plugin's** responsibility. Different
CNIs do this differently — a VXLAN overlay (encapsulate the pod packet inside a
node-to-node packet), or native routing (teach the network how to reach each node's
pod CIDR via BGP). That's Module 14.2; for now, know that **the CNI is what makes the
flat network real across nodes.**

### Pod → Service: a stable IP over shifting pods

Pods are mortal — they come and go, and their IPs change. You can't hardcode a pod IP.
A **Service** gives a stable **virtual IP (ClusterIP)** that load-balances to the
current healthy pods behind it (Module 03.3). But that ClusterIP isn't a real
interface anywhere — no machine "owns" it. So what makes traffic to it actually reach
a pod?

```text
   pod ──► 10.96.0.10:80  (Service ClusterIP — virtual, owned by nobody)
                │
                │  on the way out, the kernel REWRITES the destination:
                ▼
           10.244.2.7:8080  (a real pod IP, chosen from the Service's endpoints)
```

A component programs the kernel to **DNAT** (destination NAT) the Service IP to one of
the backing pod IPs. Classically that component is **kube-proxy**, writing `iptables`
(or IPVS) rules; with Cilium it's **eBPF** doing the same job faster (Module 14.4).
The Service's set of real pod IPs is tracked as **EndpointSlices**, updated as pods
come and go.

### DNS: names, not IPs

Developers use names (`backend`), not ClusterIPs. The cluster runs **CoreDNS**, and
every pod's `/etc/resolv.conf` points at the DNS Service. The resolution chain for a
Service follows a predictable pattern:

```text
   backend
     → backend.<namespace>.svc.cluster.local   (search-domain expansion)
     → CoreDNS returns the Service's ClusterIP
     → kube-proxy/eBPF DNAT to a real pod IP
```

- A normal Service resolves to its **ClusterIP**.
- A **headless** Service (`clusterIP: None`) resolves straight to the **pod IPs** —
  used by StatefulSets where each pod has a stable identity (Module 03.2).

> **Why this matters for debugging:** a huge fraction of "can't connect" incidents are
> *DNS*, not routing. If `nslookup backend` fails but the pod IP works, you have a DNS
> problem, not a network problem.

### kube-proxy: the Service plumber

**kube-proxy** runs on every node and watches Services and EndpointSlices, programming
the node's `iptables`/`IPVS` rules so that Service IPs DNAT to pod IPs. It does *not*
proxy packets itself in the common modes — it just configures the kernel to do the
rewriting. Its modes:

- **iptables** — the default; a chain of NAT rules. Simple, but rule evaluation scales
  linearly with Service count (slow at very large scale).
- **IPVS** — kernel-level load balancing with hash tables; scales better.
- **eBPF (Cilium)** — replaces kube-proxy entirely with eBPF programs (Module 14.4).

---

## 2. Why it matters for platform engineering

The platform team owns the network for *every* team on the cluster. When a service
can't reach its database, when DNS is flaky, when a NetworkPolicy locks something out,
the platform engineer is the one holding the pager. You cannot debug what you don't
understand:

- **A shared mental model saves incidents.** "Pod → Service → pod with a DNAT in the
  middle, names resolved by CoreDNS" is the map you follow under pressure.
- **Security is built on this layer.** Default-deny isolation (Module 14.3) and
  zero-trust L7 policy (Module 13.8) only make sense once you know the default is a
  wide-open flat network.
- **It's the substrate for ingress and mesh.** The Gateway API (14.5) and service
  meshes (14.6) are elaborations on these fundamentals.

## 3. Mental model

```text
   NAME            IP LAYER              WHO MAKES IT WORK
   ─────           ────────              ─────────────────
   backend     →   Service ClusterIP  →  CoreDNS resolves the name
   (DNS)           10.96.0.10            kube-proxy / eBPF DNATs ClusterIP → pod IP
                        │
                        ▼
   pod IP          10.244.2.7            CNI makes pod IPs routable (flat, no NAT)
   (real)              :8080             veth pair + bridge (same node)
                                         overlay/routing (across nodes)

   Debug top-down: name resolves? → Service has endpoints? → pod reachable at its IP?
```

One sentence: **names resolve to Service IPs, Service IPs get rewritten to pod IPs,
and the CNI makes every pod IP directly reachable on a flat network.**

## 4. Minimal implementation

You don't need a diagram to believe the flat network — you can watch a packet get
rewritten. On a kind cluster, deploy a Service and inspect the actual kernel rules:

```bash
kubectl create deployment web --image=nginx --replicas=2
kubectl expose deployment web --port=80

# The Service has a virtual ClusterIP owned by no interface:
kubectl get svc web          # e.g. 10.96.0.10

# The real backends behind it (EndpointSlices):
kubectl get endpointslices -l kubernetes.io/service-name=web

# On a node, the DNAT rules that rewrite ClusterIP -> pod IP:
docker exec <kind-node> iptables -t nat -L KUBE-SERVICES -n | grep 10.96.0.10
```

You'll see a rule matching the Service IP that jumps to a chain which DNATs to one of
the pod IPs. That rule *is* the Service. Delete a pod, watch the EndpointSlice and the
rule update. The lab walks this end to end.

## 5. Hands-on lab

Trace a request from a pod, through a Service, to a backing pod on a local cluster —
watching DNS resolve the name, the EndpointSlice list the real pods, and the iptables
DNAT rule do the rewrite. Then break DNS and see the difference between a *name*
problem and a *routing* problem.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **DNS is the usual suspect.** At scale, CoreDNS load, `ndots` search-domain
  expansion, and caching cause subtle latency. Monitor CoreDNS and consider NodeLocal
  DNSCache. When debugging, test the name *and* the IP to localize the fault.
- **kube-proxy iptables scaling.** Thousands of Services mean long iptables chains and
  slow rule updates. IPVS or an eBPF dataplane (Cilium) scale far better — a real
  reason platforms adopt Cilium (Module 14.4, and Project 1's
  [ADR-002](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md)).
- **Pod CIDR sizing.** The pod network has a finite address space; undersizing the pod
  CIDR caps how many pods the cluster can ever run. Plan it at cluster creation.
- **MTU mismatches.** Overlays (VXLAN) add encapsulation overhead; a wrong MTU causes
  mysterious hangs on large payloads while small requests work. A classic gotcha.
- **The flat network is wide open by default.** Requirement #2 (any pod reaches any
  pod) is also a security problem until you add NetworkPolicies (Module 14.3).

## 7. Common mistakes

- **Assuming "can't connect" means a routing problem.** — It's usually DNS or a missing
  Service endpoint. *Fix:* debug top-down — resolve the name, check EndpointSlices,
  then test the pod IP.
- **Hardcoding pod IPs.** — Pods are ephemeral; their IPs change on restart. *Fix:*
  always go through a Service (a stable name/ClusterIP).
- **Forgetting the Service has no endpoints.** — A Service with a wrong selector
  matches no pods and silently blackholes traffic. *Fix:* `kubectl get endpointslices`
  — empty means the selector is wrong (you saw this in the Project 1 debugging lab).
- **Expecting NodePort/ClusterIP to be reachable from outside.** — ClusterIP is
  cluster-internal only. *Fix:* use a LoadBalancer, NodePort, or the Gateway API
  (14.5) for external access.
- **Ignoring MTU on overlays.** — Large responses hang while health checks pass. *Fix:*
  set the CNI MTU correctly for your underlay.

## 8. Assessment

**Knowledge checks**

1. State the Kubernetes networking model's core rule about pod-to-pod traffic and NAT.
2. On the same node, what two kernel constructs connect a pod to the node's network?
3. When a pod sends to a Service ClusterIP, what happens to the packet's destination,
   and which component programmed that?
4. What does a **headless** Service resolve to, and when would you use one?
5. Does kube-proxy proxy packets in its default mode? If not, what does it do?

**Concept exercise**

> Explain how one pod reaches another pod on a different node **without using the words
> "Service" or "DNS."** Describe the IP-level path and what keeps it NAT-free.

**Debugging exercise**

> A developer says "my frontend can't reach the backend." Walk through the exact
> top-down sequence of checks you'd run, and what each result would tell you.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Every pod gets a unique IP and can reach every other pod directly, with **no
  NAT** — a flat network.
- **Q2:** A **veth pair** (one end in the pod's netns as `eth0`, the other in the
  node) plugged into a **bridge** (e.g. `cni0`) that connects all pods on the node.
- **Q3:** The destination IP is **DNAT-rewritten** from the virtual ClusterIP to a real
  pod IP, programmed by **kube-proxy** (iptables/IPVS) or **eBPF** (Cilium).
- **Q4:** A headless Service (`clusterIP: None`) resolves to the **pod IPs** directly;
  used for StatefulSets / when clients need per-pod identity.
- **Q5:** No — in iptables/IPVS mode it doesn't handle packets; it **programs the
  kernel** (iptables/IPVS rules) so the kernel does the DNAT/load-balancing.
- **Debugging:** (1) `nslookup backend` from the frontend pod — DNS working? (2)
  `kubectl get svc backend` — does it exist, right port? (3) `kubectl get
  endpointslices` — any endpoints, or is the selector wrong? (4) `kubectl exec` curl
  the **pod IP** directly — pod healthy/listening? (5) check NetworkPolicies — is
  traffic being denied (Module 14.3)? Each step localizes the fault to name → Service
  → endpoints → pod → policy.

</details>

## 9. Further reading

- Kubernetes — [Cluster Networking (the model)](https://kubernetes.io/docs/concepts/cluster-administration/networking/)
- Kubernetes — [Service](https://kubernetes.io/docs/concepts/services-networking/service/)
  and [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- Kubernetes — [Virtual IPs and Service Proxies (kube-proxy)](https://kubernetes.io/docs/reference/networking/virtual-ips/)
- [A Guide to the Kubernetes Networking Model (Julia Evans)](https://jvns.ca/blog/2016/12/22/container-networking/)
- [CNI specification](https://github.com/containernetworking/cni/blob/main/SPEC.md)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 11 overview](../README.md) · _Next:_ [14.2 — CNI Plugins →](../02-cni-plugins/)
