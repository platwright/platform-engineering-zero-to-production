# Module 14.4 — Cilium and eBPF

> Everything so far has pointed here. Vanilla NetworkPolicy can't do FQDN or L7; kube-
> proxy's iptables don't scale; and you've had no way to *see* network flows. **Cilium**
> — built on **eBPF** — answers all three: it's a CNI, an L7-aware policy engine,
> kube-proxy replacement, and (via **Hubble**) a network-observability tool, all in
> one. This is the CNI the course chose in
> [Project 1's ADR-002](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md).

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 14.3](../03-network-policies/), Docker, and
[kind](https://kind.sigs.k8s.io/). The lab installs Cilium locally.

## Learning objectives

By the end of this module you will be able to:

- Explain what **eBPF** is and why it's faster and safer than kernel modules.
- Describe what Cilium provides: CNI, L7 policy, kube-proxy replacement, observability.
- Use **Hubble** to see allowed and dropped network flows.
- Write a **Cilium L7** policy (e.g. allow `GET /api` but not `DELETE`).
- Explain **DNS-based egress** and when Cilium is worth its complexity.

---

## 1. Concept

For the datapath flow, see [Cilium eBPF path](../../diagrams/network/cilium-ebpf-path.png).

### eBPF in one paragraph

**eBPF** (extended Berkeley Packet Filter) lets you run small, sandboxed programs
**inside the Linux kernel** — attached to hooks like "a packet arrived" or "a syscall
happened" — **without writing a kernel module or rebooting**. The kernel verifies each
program is safe (bounded loops, no bad memory access) before running it, so a bug
can't crash the kernel. For networking, this means packet processing logic that runs at
kernel speed, updatable at runtime:

```text
   Traditional (iptables):  a long, linear chain of rules the kernel walks per packet
                            — slow to evaluate and update at thousands of Services.

   eBPF (Cilium):           a verified program at the network hook, using hash-map
                            lookups — O(1)-ish, updated live, no rule-chain walk.
```

eBPF is also the foundation of Falco's runtime security (Module 13.7) — same kernel
technology, different hook. It's one of the most important shifts in Linux
infrastructure of the last decade.

### What Cilium is (four tools in one)

Cilium uses eBPF to deliver, in a single component, what used to take several:

```text
   ┌─────────────────────── Cilium (eBPF dataplane) ───────────────────────┐
   │ 1. CNI                 pod networking (the flat network, Module 14.1)   │
   │ 2. NetworkPolicy++     L3/L4 AND L7 (HTTP/gRPC/DNS) + FQDN egress       │
   │ 3. kube-proxy replace  Service load-balancing in eBPF (no iptables)     │
   │ 4. Observability       Hubble: every flow, allowed or dropped, with id  │
   └────────────────────────────────────────────────────────────────────────┘
```

- **CNI** — it implements the flat pod network (Module 14.1), replacing kindnet/Flannel/
  Calico as the dataplane.
- **Policy beyond L4** — standard NetworkPolicy **plus** CiliumNetworkPolicy, which adds
  **L7** (HTTP methods/paths, gRPC, Kafka) and **DNS/FQDN** egress — the exact gaps
  Module 14.3 ended on.
- **kube-proxy replacement** — Service DNAT (Module 14.1) done in eBPF, which scales far
  better than iptables chains at high Service counts.
- **Identity-based security** — Cilium assigns a security **identity** to each workload
  (from its labels) and enforces policy on identity, not IP — the basis for zero trust
  and mTLS (Module 13.8).

### Hubble: finally, you can see the network

The single biggest day-to-day win is **Hubble** — Cilium's observability layer. Because
eBPF sits in the datapath, Hubble sees **every flow**: source and destination identity,
port, verdict (FORWARDED or DROPPED), and even L7 details (the HTTP method and path).

```bash
hubble observe --namespace team-a --follow            # watch live flows
hubble observe --verdict DROPPED --follow             # see exactly what policy dropped
```

This turns NetworkPolicy debugging from guesswork ("is it blocked? I can't tell") into
observation ("that DROPPED flow is attacker→backend, denied by policy X"). It's the
missing piece from Module 14.3's "a wrong policy is an invisible outage."

### L7 and DNS policy: closing the gaps

A **CiliumNetworkPolicy** can express what vanilla NetworkPolicy cannot:

```yaml
# Allow frontend -> backend, but ONLY HTTP GET /api/* (not POST/DELETE, not other paths)
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: allow-get-api
  namespace: team-a
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/.*"
```

And **DNS-based egress** — "allow only `api.github.com`" — which is impossible with
CIDR-only vanilla policy:

```yaml
# (sketch) allow egress only to a specific FQDN
egress:
  - toFQDNs:
      - matchName: "api.github.com"
    toPorts:
      - ports:
          - port: "443"
            protocol: TCP
```

These are the rules real platforms need (allow this API, this HTTP verb) and the reason
teams adopt Cilium despite its learning curve.

### When Cilium is worth it

Cilium is powerful but adds real conceptual surface (eBPF, identities, its own CRDs). It
earns its place when you need:

- **L7 or FQDN policy** (allow specific APIs/verbs) — not expressible otherwise.
- **Flow observability** (Hubble) — invaluable for multi-tenant platforms.
- **Scale** — eBPF service LB beats iptables at high Service counts.
- **A path to mTLS / zero trust** (Module 13.8) and **multi-cluster** (Cluster Mesh).

For a tiny single-tenant cluster, it may be more than you need — but for a *platform*
serving many teams, these are table stakes, which is why it's the course default.

---

## 2. Why it matters for platform engineering

Cilium is a platform **force multiplier**: one component replaces a CNI, a policy
engine, kube-proxy, and a network-observability tool, with capabilities none of the
individual pieces had:

- **It makes zero trust achievable.** Identity-based, L7-aware policy + mTLS is the
  concrete mechanism behind Module 13.8's principles.
- **Hubble turns network incidents from invisible to obvious**, which directly reduces
  MTTR for the whole cluster — a platform-wide DX and reliability win.
- **It's the dataplane managed clusters are standardizing on** (GKE Dataplane V2 is
  Cilium), so understanding it is increasingly non-optional.

The trade-off — operability and learning curve — is exactly the kind of build-vs-adopt,
capability-vs-complexity decision a platform team must own (and document, as Project 1
did in ADR-002).

## 3. Mental model

```text
   eBPF = safe, verified programs in the kernel, at the network hook, updated live.

   Cilium rides eBPF to be FOUR things at once:
       CNI  +  L7/FQDN policy  +  kube-proxy replacement  +  Hubble observability
        │             │                    │                        │
   flat network   allow GET /api,      Service LB without      SEE every flow,
   (Module 14.1)  only api.github.com  iptables chains         allowed or DROPPED

   Identity (from labels), not IP, is what policy is enforced on → zero trust.
```

One sentence: **Cilium uses eBPF to be your CNI, your L7-aware policy engine, your
kube-proxy, and your network microscope — enforcing on workload identity, not IP.**

## 4. Minimal implementation

The quickest way to feel the difference is Hubble. On a Cilium cluster, you *watch* the
policy decisions you made in Module 14.3 instead of inferring them:

```bash
# Apply a default-deny, then observe the drops in real time
kubectl apply -f default-deny.yaml
hubble observe --namespace team-a --verdict DROPPED --follow
# Each blocked connection shows: source identity -> dest identity : DROPPED (Policy denied)
```

Where Module 14.3 left you curling and guessing, Hubble shows the verdict and the
reason. The lab installs Cilium + Hubble and has you watch an L7 policy allow a GET and
drop a DELETE — a decision vanilla NetworkPolicy literally cannot make.

## 5. Hands-on lab

Install Cilium with Hubble on a local cluster, watch allowed and dropped flows in real
time, then apply an **L7** CiliumNetworkPolicy that allows `GET /` but blocks other
HTTP methods — and see Hubble report each verdict with the HTTP detail.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Operability is the real cost.** eBPF, Cilium identities, and its CRDs are a genuine
  learning curve; the platform team operates this for everyone. Budget training and
  runbooks (ADR-002 named this trade-off).
- **Kernel version matters.** eBPF features depend on the kernel; verify your nodes'
  kernels support the Cilium features you want (L7, kube-proxy replacement).
- **L7 policy adds a proxy hop.** L7 enforcement routes through an Envoy proxy in
  Cilium — slightly more latency and resource use than pure L3/L4. Use L7 where it
  earns its keep, not everywhere.
- **Retain Hubble flow data.** Hubble's live view is great, but for incident
  forensics, export flows to a backend (and mind the volume/cost — a FinOps concern).
- **On managed clusters, know what you get.** GKE Dataplane V2 is Cilium but
  managed/limited; self-installed Cilium gives more control but you own upgrades.
- **FQDN policy depends on DNS visibility.** Cilium learns FQDN→IP by watching DNS; make
  sure DNS egress goes through Cilium so `toFQDNs` rules work.

## 7. Common mistakes

- **Adopting Cilium for a problem you don't have.** — On a tiny single-tenant cluster,
  the complexity may exceed the benefit. *Fix:* adopt it for L7/FQDN/observability/scale
  needs, not hype.
- **Expecting L7 rules on a kernel that can't.** — Features silently unavailable on old
  kernels. *Fix:* check kernel/Cilium compatibility before relying on L7.
- **Ignoring Hubble.** — Teams install Cilium and still debug blind. *Fix:* enable
  Hubble; it's the biggest operational win.
- **Mixing vanilla and Cilium policies without understanding precedence.** — Confusing
  allow/deny interactions. *Fix:* standardize on CiliumNetworkPolicy where you need L7,
  and learn how they compose.
- **FQDN egress without DNS going through Cilium.** — `toFQDNs` rules don't match
  because Cilium never saw the lookup. *Fix:* route DNS through Cilium.

## 8. Assessment

**Knowledge checks**

1. What is eBPF, and why is it safer than loading a kernel module?
2. Name the four things Cilium provides in one component.
3. What does Hubble let you see that vanilla NetworkPolicy debugging cannot?
4. Give one policy rule Cilium can express that vanilla NetworkPolicy cannot.
5. Cilium enforces policy on *identity* rather than IP. Why does that matter for a
   dynamic, multi-tenant cluster?

**Concept exercise**

> Explain the advantage of Cilium's eBPF dataplane over iptables **without using the
> word "eBPF."** Focus on how each decides what to do with a packet and why one scales.

**Trade-off exercise**

> A platform team runs 40 teams on one cluster and keeps having "is this connection
> blocked or not?" debates and slow Service load-balancing at high Service counts. They
> currently use a simple CNI. Make the case for (or against) migrating to Cilium, and
> name the main risk.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** eBPF runs sandboxed, kernel-**verified** programs at kernel hooks without a
  module or reboot; the verifier rejects unsafe programs, so a bug can't crash the
  kernel (unlike a buggy module).
- **Q2:** CNI, L7/FQDN-aware network policy, kube-proxy replacement, and observability
  (Hubble).
- **Q3:** Every flow with its verdict (FORWARDED/DROPPED) and the reason, by workload
  identity — turning invisible policy decisions into observable ones.
- **Q4:** L7 rules (e.g. allow `GET /api/*` but not `DELETE`) or DNS/FQDN egress (allow
  `api.github.com`) — neither is expressible in vanilla NetworkPolicy.
- **Q5:** Pod IPs churn constantly; enforcing on identity (derived from stable labels)
  means policy stays correct as pods are rescheduled and IPs change — essential for
  zero trust.
- **Trade-off:** Strong case *for*: Hubble ends the "blocked or not?" debates (flow
  visibility), and eBPF service LB fixes the iptables-at-scale slowness; it also opens
  L7 policy and a zero-trust path. Main risk: operability/learning curve and a
  disruptive CNI migration on a live multi-tenant cluster — plan and test it carefully
  (ADR-002's exact trade-off).

</details>

## 9. Further reading

- [Cilium documentation](https://docs.cilium.io/) and [Hubble](https://docs.cilium.io/en/stable/observability/hubble/)
- [CiliumNetworkPolicy (L7 + DNS)](https://docs.cilium.io/en/stable/security/policy/)
- [eBPF.io — what is eBPF?](https://ebpf.io/what-is-ebpf/)
- [GKE Dataplane V2](https://cloud.google.com/kubernetes-engine/docs/concepts/dataplane-v2)
- [Project 1 · ADR-002 — Why Cilium](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [14.3 — Network Policies](../03-network-policies/) · _Next:_ [14.5 — Kubernetes Gateway API →](../05-kubernetes-gateway-api/)
