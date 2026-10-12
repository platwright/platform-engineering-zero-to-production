# Interview Prep — Networking

> This domain tests whether you can reason from one rule — the flat pod network —
> up to Services, DNS, policy, and ingress, and know when a service mesh is
> overkill. Interviewers probe DNAT, default-deny, eBPF, and the Gateway API.
> Practice tracing a packet from a client to a pod out loud before checking the
> model answer.

## The pod network

### Q: What is the one rule of Kubernetes networking?

**What they're really asking:** Do you hold the flat-network mental model?

The model reduces to one rule: **every pod gets its own IP and can reach every other
pod directly, with no NAT**, as if all pods sat on one flat network. A pod sees its
own IP as the same IP others use to reach it (no NAT surprises), and containers
**within** a pod share the network namespace and talk over `localhost`. This single
rule explains almost every "why can't X reach Y?" question.

**Going deeper:** [14.1 · Kubernetes Networking Fundamentals](../14-kubernetes-networking/01-kubernetes-networking-fundamentals/) and [03.3 · Services and Networking](../03-kubernetes-fundamentals/03-services-and-networking/)

**Red flags:** Thinking pods NAT to the node IP to reach each other.

### Q: What is a CNI, and what is it responsible for?

**What they're really asking:** Do you know who actually makes the flat network real?

The **Container Network Interface** is a spec plus plugins the kubelet invokes when a
pod is created. The CNI handles pod **IP address management**, creates the pod's
virtual interface (a veth pair into the node), and programs routes so the flat network
works **across nodes** — via an overlay (VXLAN) or native routing/BGP. Examples:
Cilium, Calico, flannel. Many CNIs also enforce **NetworkPolicy**; a CNI without
policy support silently ignores policies.

**Going deeper:** [14.2 · CNI Plugins](../14-kubernetes-networking/02-cni-plugins/)

### Q: How does traffic reach a pod behind a Service?

**What they're really asking:** Do you understand the virtual IP and DNAT?

A Service's **ClusterIP** is a stable **virtual IP** with nothing listening on it
directly. **CoreDNS** resolves the Service name to that ClusterIP. A node-level
component — classically **kube-proxy** programming `iptables`/`IPVS`, or **eBPF** with
Cilium — then **DNATs** the ClusterIP to one of the healthy backing pod IPs listed in
the Service's **EndpointSlices**, load-balancing per connection. So the name gives a
stable address, and the kernel rewrites it to a real pod on each new connection.

```text
client → Service DNS name → ClusterIP (virtual)
       → kube-proxy / eBPF DNAT → a ready pod IP from EndpointSlices
```

**Going deeper:** [14.1 · Kubernetes Networking Fundamentals](../14-kubernetes-networking/01-kubernetes-networking-fundamentals/)

**Red flags:** Believing the ClusterIP is a real interface on a pod or node.

### Q: What are the Service types and when do you use each?

**What they're really asking:** Do you know how workloads get exposed?

- **ClusterIP** (default) — internal virtual IP, reachable only inside the cluster.
- **NodePort** — opens a port on every node that forwards to the Service; basic external access, usually a building block under something else.
- **LoadBalancer** — provisions an external cloud load balancer (or MetalLB on-prem) pointing at the Service.
- **Headless** (`clusterIP: None`) — returns pod IPs directly via DNS for StatefulSets and client-side load balancing.

For HTTP you usually front services with an **Ingress or Gateway**, not one cloud load balancer per service.

**Going deeper:** [03.3 · Services and Networking](../03-kubernetes-fundamentals/03-services-and-networking/)

### Q: How does DNS work in Kubernetes?

**What they're really asking:** Do you understand in-cluster service discovery?

**CoreDNS** runs as a cluster Service, and every pod's `/etc/resolv.conf` points at
it. Services get A records of the form `name.namespace.svc.cluster.local`, and search
domains let you use short names within a namespace. Headless Services and StatefulSets
get per-pod records for stable identity. DNS is the backbone of service discovery —
you address a Service by name and let DNS plus DNAT find a pod.

**Going deeper:** [14.1 · Kubernetes Networking Fundamentals](../14-kubernetes-networking/01-kubernetes-networking-fundamentals/)

## Policy and data plane

### Q: What is a NetworkPolicy, and what does default-deny mean?

**What they're really asking:** Do you know pods are open by default and how to lock them down?

A **NetworkPolicy** is a namespaced resource that selects pods and allows specific
ingress/egress to peers (pods, namespaces, or CIDRs) on given ports. Crucially, pods
are **allow-all by default**; the moment a policy selects a pod for a direction, that
direction becomes **deny-by-default** and only the listed traffic is permitted.
**Default-deny** means applying a policy that selects all pods with no allow rules,
then explicitly allowing required flows — a zero-trust posture **inside** the cluster.
Enforcement is the CNI's job (Cilium, Calico).

**Going deeper:** [14.3 · Network Policies](../14-kubernetes-networking/03-network-policies/) and [13.8 · Zero Trust for Platforms](../13-security-and-policy-engineering/08-zero-trust-for-platforms/)

**Red flags:** Assuming namespaces isolate traffic by themselves, or forgetting egress rules.

### Q: What problems do Cilium and eBPF solve over kube-proxy and iptables?

**What they're really asking:** Do you know why the data plane is moving to eBPF?

kube-proxy's `iptables` mode builds rule chains that grow **linearly** with the number
of Services, so updates and lookups slow down at scale. **eBPF** runs sandboxed
programs **inside the kernel**, so **Cilium** implements Service load-balancing, policy,
and routing as efficient hash-table lookups and can **replace kube-proxy** entirely.
Benefits: better performance at scale, **identity-based** (not IP-based) policy, **L7**
policy, and deep observability — all without per-pod sidecars.

**Going deeper:** [14.4 · Cilium and eBPF](../14-kubernetes-networking/04-cilium-and-ebpf/)

### Q: What is Hubble?

**What they're really asking:** Do you know Cilium's observability layer?

**Hubble** is Cilium's eBPF-based network observability tool. Because eBPF sees traffic
in the kernel, Hubble provides flow visibility (who talked to whom at L3/L4/L7, DNS
queries, and policy drops) and a live service map **without changing application
code** — which makes debugging connectivity and verifying NetworkPolicy far easier.

**Going deeper:** [14.4 · Cilium and eBPF](../14-kubernetes-networking/04-cilium-and-ebpf/)

## Ingress and mesh

### Q: What is the Gateway API, and how does it improve on Ingress?

**What they're really asking:** Do you know the successor to Ingress and its role model?

Ingress is the old HTTP routing API: simple, but limited and extended through a sprawl
of controller-specific annotations that are not portable. The **Gateway API** is its
successor — a richer, extensible, **role-oriented** set of resources:

- **GatewayClass** — the type of infrastructure (provided by the platform/infra team).
- **Gateway** — an actual listener/load balancer (owned by the platform operator).
- **HTTPRoute** / **TCPRoute** — routing rules (owned by app developers).

It supports header- and weight-based routing, traffic splitting, cross-namespace
routing, and multiple protocols in a portable way, and it cleanly separates platform
from application concerns — a natural fit for a platform team's paved road.

**Going deeper:** [14.5 · Kubernetes Gateway API](../14-kubernetes-networking/05-kubernetes-gateway-api/)

**Red flags:** Encoding critical routing behavior in controller-specific Ingress annotations with no portability.

### Q: What is a service mesh, and when should you NOT use one?

**What they're really asking:** Do you weigh mesh value against its real complexity cost?

A service mesh (Istio, Linkerd, or Cilium's mesh) adds a data plane — sidecar or
node-level proxies — that transparently provides **mTLS**, **L7 traffic management**
(retries, timeouts, canary, traffic splitting), and uniform **telemetry** between
services, without application code. The value is real when you need **org-wide
mTLS**, fine-grained L7 control, or consistent cross-team observability.

**When not to use one:** if you have a handful of services and do not need mTLS or
advanced routing, the operational complexity, latency, and resource overhead are not
worth it. Start with **NetworkPolicy**, a **Gateway**, and good client libraries, and
adopt a mesh only when a concrete need appears. Consider sidecar-less or ambient modes
to cut overhead. Never add a mesh "because it is best practice."

**Going deeper:** [14.6 · Service Mesh Reference](../14-kubernetes-networking/06-service-mesh-reference/)

**Red flags:** Deploying Istio on day one for three services, or citing "best practice" with no stated need.
