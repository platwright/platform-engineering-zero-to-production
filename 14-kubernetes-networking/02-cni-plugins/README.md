# Module 14.2 — CNI Plugins

> The flat pod network from Module 14.1 doesn't implement itself. A **CNI plugin** is
> the component that actually gives each pod an IP and makes pod IPs routable across
> nodes. Which CNI you pick shapes your cluster's performance, its NetworkPolicy
> capabilities, and how you debug it — so this module explains what the CNI does, how
> pods get IPs (IPAM), how Flannel/Calico/Cilium differ, and how to diagnose the
> classic "pod stuck in ContainerCreating" failure.

**Estimated effort:** ~1.5–2 hours (theory + lab)
**You'll need:** [Module 14.1](../01-kubernetes-networking-fundamentals/), Docker, and
[kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain what the **CNI specification** requires a plugin to do.
- Describe **IPAM** — how a pod gets its IP, and what happens when the pool runs out.
- Compare **Flannel**, **Calico**, and **Cilium** on the criteria that matter.
- Diagnose a pod stuck in **ContainerCreating** due to a CNI problem.
- Choose a CNI on real requirements, not hype.

---

## 1. Concept

### What the CNI is

**CNI (Container Network Interface)** is a small, deliberately minimal specification:
when the kubelet creates a pod, it calls a CNI plugin binary and asks it to **set up
the pod's network**; when the pod dies, it asks the plugin to **tear it down**. That's
essentially the whole contract:

```text
   kubelet creates a pod
        │  "ADD: give this pod a network"
        ▼
   CNI plugin (a binary in /opt/cni/bin, configured in /etc/cni/net.d)
        ├─ allocate an IP for the pod            (IPAM)
        ├─ create the veth pair + wire the bridge (Module 14.1)
        └─ set up routes so the pod IP is reachable across nodes
        │  "DEL" on pod teardown → release the IP, remove the plumbing
```

The CNI is what turns the *rule* ("every pod has a routable IP, no NAT") into reality.
Without a working CNI, pods can't get an IP at all — which is exactly the
ContainerCreating failure below.

### IPAM: how a pod gets its IP

**IPAM (IP Address Management)** is the part of the CNI that hands out pod IPs. The
cluster has a **pod CIDR** (e.g. `10.244.0.0/16`), usually carved into a per-node
slice (e.g. each node gets a `/24`). When a pod is created, IPAM picks a free address
from the local node's slice.

Two consequences platform engineers must plan for:

- **The pod CIDR is a hard ceiling.** If every node gets a `/24` (254 usable IPs), no
  node can ever run more than ~254 pods, and the whole `/16` caps the cluster. Size it
  at cluster creation — you can't easily change it later.
- **IP exhaustion is a real outage.** When IPAM has no free address, new pods stick in
  ContainerCreating. On cloud CNIs that assign *real* VPC IPs (like AWS VPC CNI), you
  can exhaust the *subnet*, not just a pod CIDR.

### The field: Flannel, Calico, Cilium

Dozens of CNIs exist; three represent the common design points:

```text
   FLANNEL          simple overlay (VXLAN). Easy, few features.
                    NO NetworkPolicy of its own. Good for learning / simple clusters.

   CALICO           L3 routing (often BGP) or overlay. Mature, rich NetworkPolicy.
                    Scales well; the long-time default for policy-heavy clusters.

   CILIUM           eBPF-based. CNI + L7-aware policy + observability (Hubble) +
                    kube-proxy replacement + cluster mesh. Most capable, most to learn.
```

- **Flannel** — a straightforward VXLAN overlay: wrap each pod packet inside a
  node-to-node UDP packet. Minimal and reliable, but it has **no NetworkPolicy
  enforcement** of its own, so you can't do default-deny with Flannel alone.
- **Calico** — can run as a pure L3 router (advertising each node's pod routes via
  **BGP**, no encapsulation overhead) or as an overlay. Rich, mature NetworkPolicy
  support; a very common production choice.
- **Cilium** — uses **eBPF** (Module 14.4) instead of iptables for the dataplane,
  adding L7-aware policy, deep observability (Hubble), kube-proxy replacement, and
  multi-cluster mesh. The most powerful — and the course's choice
  ([Project 1 ADR-002](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md)) —
  at the cost of more concepts to learn.

### Overlay vs native routing

A recurring axis across CNIs:

- **Overlay (encapsulation)** — wrap the pod packet inside a node-to-node packet
  (VXLAN/Geneve). Works on almost any underlying network because the underlay only
  sees node-to-node traffic. Cost: encapsulation overhead and **MTU** care (Module
  14.1's gotcha).
- **Native routing** — no wrapping; the underlying network is taught how to reach each
  node's pod CIDR (via BGP or cloud route tables). Faster, but needs an underlay you
  control or a cloud that integrates.

### Choosing a CNI

Decide on requirements, not fashion:

- **Do you need NetworkPolicy?** (Almost always yes, for isolation — Module 14.3.)
  Then not Flannel-alone.
- **Do you need L7 policy, mTLS, or deep flow observability?** Cilium.
- **What's your scale and underlay?** BGP-native (Calico) or eBPF (Cilium) scale
  better than iptables-heavy setups.
- **What can your team operate?** Cilium is powerful but has the steepest learning
  curve. A platform runs the CNI for everyone — operability counts.
- **Managed clusters often choose for you.** GKE Dataplane V2 *is* Cilium; other
  managed offerings bundle a default. Know what you're getting.

---

## 2. Why it matters for platform engineering

The CNI is a **cluster-wide, hard-to-change foundation**. You pick it once (usually at
cluster creation), and every team's networking, security policy, and observability
inherit its capabilities and limits:

- Choose Flannel and you've quietly ruled out default-deny isolation.
- Choose Cilium and you've unlocked L7 policy and Hubble — but taken on eBPF to
  operate.
- Mis-size the pod CIDR and you cap cluster growth from day one.

It's also the layer behind the most alarming-looking failures (every pod on a node
stuck ContainerCreating), so the platform team must be able to diagnose it fast.

## 3. Mental model

```text
   CNI = the plugin kubelet calls to NETWORK a pod.

   It does three things:        and it's chosen on:
   ┌───────────────────────┐    ┌──────────────────────────────┐
   │ 1. IPAM: give an IP    │    │ NetworkPolicy support?        │
   │ 2. Wire veth + bridge  │    │ L7 / observability / mTLS?    │
   │ 3. Make it routable    │    │ overlay vs native routing?    │
   │    (overlay or routes) │    │ scale + operability?          │
   └───────────────────────┘    └──────────────────────────────┘

   No CNI working  ⇒  no pod IP  ⇒  ContainerCreating forever.
```

One sentence: **the CNI gives each pod a routable IP and sets the ceiling on your
cluster's policy, performance, and observability — choose it on requirements, size the
pod CIDR up front.**

## 4. Minimal implementation

You can *see* the CNI's output without touching its internals. The config that tells
kubelet which plugin to use, and the IP it handed a pod, are both inspectable:

```bash
# Which CNI config is active on a node?
docker exec <kind-node> ls /etc/cni/net.d
docker exec <kind-node> cat /etc/cni/net.d/*            # the plugin + its IPAM config

# The pod CIDR assigned to each node (IPAM's pool):
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.podCIDR}{"\n"}{end}'

# A pod's IP came from its node's slice of that CIDR:
kubectl get pods -o wide
```

kind ships a simple default CNI (kindnet). The lab swaps in Calico or Cilium so you
can watch policy support and the dataplane change under the same workloads.

## 5. Hands-on lab

Compare CNIs hands-on: create a cluster, observe its default CNI and IPAM, then
diagnose a pod stuck in **ContainerCreating** and fix it. You'll see why "no CNI = no
IP = ContainerCreating" and how to read the signal.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Size the pod CIDR for the cluster's lifetime.** It's painful to change later. Model
  max pods/node × nodes and leave headroom.
- **Pick the CNI for the capabilities you'll need in a year**, not just today —
  especially NetworkPolicy and observability. Migrating CNIs on a live cluster is a
  major, risky operation.
- **Know your managed cluster's CNI.** GKE Dataplane V2 is Cilium; EKS defaults to the
  AWS VPC CNI (real VPC IPs → mind subnet exhaustion). The default shapes everything.
- **Monitor IP exhaustion.** Alert before the pool fills; exhaustion presents as new
  pods stuck ContainerCreating with no obvious app cause.
- **Account for overlay MTU.** Set the CNI MTU correctly or suffer intermittent
  large-payload hangs.

## 7. Common mistakes

- **Choosing Flannel then needing NetworkPolicy.** — Flannel alone can't enforce
  policy, so default-deny isolation is impossible. *Fix:* pick a policy-capable CNI
  (Calico/Cilium) from the start, or run a policy plugin alongside.
- **Under-sizing the pod CIDR.** — Caps pods-per-node and total cluster size forever.
  *Fix:* size generously at creation.
- **Blaming the app for ContainerCreating.** — It's almost always CNI/IPAM (no IP, no
  plugin, or a failed node agent), not the container. *Fix:* `kubectl describe pod` →
  read the CNI error in Events.
- **Ignoring subnet exhaustion on cloud CNIs.** — VPC-IP CNIs exhaust real subnets, not
  just a pod CIDR. *Fix:* size subnets and use prefix delegation where available.
- **Treating the CNI as swappable.** — It's a foundational, disruptive change. *Fix:*
  choose deliberately; migrate only with a tested plan.

## 8. Assessment

**Knowledge checks**

1. In one sentence, what does a CNI plugin do when the kubelet creates a pod?
2. What is IPAM, and what symptom appears when its address pool is exhausted?
3. Why can't you implement default-deny NetworkPolicy with Flannel alone?
4. Give the main trade-off between an **overlay** CNI and a **native-routing** CNI.
5. A whole node's new pods are stuck in ContainerCreating. Is the app the likely
   cause? Where do you look first?

**Concept exercise**

> Explain why the choice of CNI constrains a platform's security and observability
> **without naming Flannel, Calico, or Cilium.** Talk in terms of capabilities.

**Trade-off exercise**

> Your team is bootstrapping a new platform cluster. One engineer wants Flannel
> ("simplest"), another wants Cilium ("most powerful"). You need default-deny
> isolation and flow visibility, and the team is small. What do you choose and why,
> and what's the cost of your choice?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** It sets up the pod's networking — allocates an IP (IPAM), creates the
  veth/bridge plumbing, and makes the pod IP routable — and tears it down on delete.
- **Q2:** IPAM hands out pod IPs from the pod CIDR; exhaustion makes new pods stick in
  **ContainerCreating** with no free address.
- **Q3:** Flannel provides connectivity only — it has no NetworkPolicy enforcement, so
  there's nothing to apply a default-deny rule.
- **Q4:** Overlay works on almost any underlay but adds encapsulation overhead and MTU
  concerns; native routing is faster but needs an underlay/cloud that can route each
  node's pod CIDR.
- **Q5:** No — ContainerCreating at the node level is almost always CNI/IPAM (plugin
  not ready, node agent down, or IPs exhausted). Look at `kubectl describe pod` Events
  and the CNI/agent pods on that node.
- **Trade-off:** Given default-deny + flow visibility are hard requirements, Flannel is
  out (no policy). Cilium meets both (NetworkPolicy + Hubble) and is the course
  default — the cost is the eBPF/Cilium learning curve for a small team; Calico would
  also satisfy policy with a gentler curve but weaker built-in observability. Choose
  Cilium and budget for the learning, or Calico if the team can't absorb eBPF yet.

</details>

## 9. Further reading

- [CNI specification](https://github.com/containernetworking/cni/blob/main/SPEC.md)
- Kubernetes — [Network Plugins](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/network-plugins/)
- [Cilium](https://docs.cilium.io/) · [Calico](https://docs.tigera.io/calico/latest/about/) · [Flannel](https://github.com/flannel-io/flannel)
- [GKE Dataplane V2 (Cilium-based)](https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2)
- [Project 1 · ADR-002 — Why Cilium](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [14.1 — Kubernetes Networking Fundamentals](../01-kubernetes-networking-fundamentals/) · _Next:_ [14.3 — Network Policies →](../03-network-policies/)
