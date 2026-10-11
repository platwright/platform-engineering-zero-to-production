# 14 · Kubernetes Networking

> Networking is where "it works on my laptop" goes to die. A pod that can't reach its
> database, a Service that silently drops traffic, a NetworkPolicy that locks out DNS —
> these are the incidents a platform team owns for every team on the cluster. This
> phase builds Kubernetes networking from first principles (the flat pod network, the
> CNI, Services and DNS), then levels up to **default-deny security with
> NetworkPolicies**, **Cilium and eBPF**, the **Gateway API**, and a grounded look at
> **service mesh**.

**Phase 11 · 6 modules · ~10–16 hours**

## Why networking?

Every earlier phase assumed the network just works. Pods found each other, Services
load-balanced, DNS resolved. This phase opens that black box — because when it
breaks, the platform engineer is the one who has to explain *why*, and because the
platform's **security** and **traffic** guarantees are enforced here:

- **Isolation** — in [Project 1](../04-platform-project-01/) and
  [Project 2](../09-platform-project-02/) you isolated teams with namespaces, RBAC,
  and quotas. The missing layer is the *network*: by default every pod can reach
  every other pod. Default-deny NetworkPolicies close that gap.
- **Zero trust** — [Module 13.8](../13-security-and-policy-engineering/08-zero-trust-for-platforms/)
  introduced identity-based, L7-aware authorization. This phase shows the networking
  machinery (Cilium, eBPF, mTLS) that makes it real.
- **Ingress** — getting external traffic *in* safely, with role separation between the
  platform team and app teams, is the Gateway API's whole reason to exist.

The throughline: **understand the model first, build the smallest demonstration
yourself, then reach for the production tool (Cilium, Gateway API) — and know why.**

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Kubernetes Networking Fundamentals](./01-kubernetes-networking-fundamentals/) | The flat pod network, veth/bridges, pod-to-pod and pod-to-Service paths, DNS, kube-proxy. | A traced request from pod → Service → pod, with the iptables DNAT rules seen. |
| 2 | [CNI Plugins](./02-cni-plugins/) | What the CNI is, how pods get IPs (IPAM), and how Flannel/Calico/Cilium differ. | A CNI comparison + a diagnosed `ContainerCreating` CNI failure. |
| 3 | [Network Policies](./03-network-policies/) | Default-deny, ingress/egress, selectors, and the limits of vanilla NetworkPolicy. | A namespace locked to default-deny with selective allows (incl. DNS). |
| 4 | [Cilium and eBPF](./04-cilium-and-ebpf/) | eBPF, Cilium as CNI + L7 policy + observability, Hubble, kube-proxy replacement. | Hubble showing allowed and dropped flows; an L7 HTTP policy. |
| 5 | [Kubernetes Gateway API](./05-kubernetes-gateway-api/) | The Ingress successor: GatewayClass/Gateway/HTTPRoute role separation, traffic splitting. | A Gateway + HTTPRoute with a 90/10 canary split. |
| 6 | [Service Mesh Reference](./06-service-mesh-reference/) | What a mesh solves (mTLS, traffic mgmt, observability), Istio vs Cilium, when *not* to. | A decision memo: mesh or no mesh, and which. |

Work them in order — each builds on the last. Together they take you from "a request
left pod A and arrived at pod B, somehow" to "I can secure, route, and observe all of
the platform's traffic, and justify every component."

## Learning objectives

By the end of this phase you will be able to:

- Explain the Kubernetes networking model (flat, no-NAT pod network) and trace a
  request from pod to Service to pod, including DNS and kube-proxy's role.
- Describe what a CNI does, how IPAM assigns pod IPs, and choose a CNI on real
  criteria; diagnose common CNI failures.
- Design **default-deny** NetworkPolicies with selective ingress/egress (without
  breaking DNS), and know where vanilla NetworkPolicy stops.
- Explain eBPF and operate **Cilium** for policy, L7 rules, and Hubble observability.
- Configure the **Gateway API** with clean role separation and traffic splitting.
- Decide when a **service mesh** earns its complexity, and choose between Cilium and
  Istio.

## Prerequisites

- [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — especially
  [Services and networking](../03-kubernetes-fundamentals/03-services-and-networking/).
- [Phase 10 · Security](../13-security-and-policy-engineering/) helps — network
  policy is a security control, and [zero trust](../13-security-and-policy-engineering/08-zero-trust-for-platforms/)
  previews the Cilium L7 material.
- Core tools: Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). Some labs
  install Cilium or a Gateway controller onto a local cluster — all free.

## A note on cost

This phase runs **entirely free on your laptop**. Every lab uses a local `kind`
cluster, open-source CNIs, and local tooling — no cloud required. Where the outline
references GKE-managed gateways or cloud load balancers, the concept is shown but the
hands-on steps stay local. Always run the **Cleanup** section at the end of each lab.

---

Start with [**14.1 · Kubernetes Networking Fundamentals →**](./01-kubernetes-networking-fundamentals/)
