# Module 14.3 — Network Policies

> The flat pod network (Module 14.1) has a dark side: by default, **every pod can talk
> to every other pod**, across every namespace. One compromised workload can reach your
> whole cluster. **NetworkPolicies** close that door — you start from **default-deny**
> and open only the exact flows each workload needs. This is the network half of the
> isolation you built with namespaces, RBAC, and quotas in Projects 1 and 2.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 14.1](../01-kubernetes-networking-fundamentals/),
[Module 14.2](../02-cni-plugins/) (a **policy-capable CNI**), Docker, and
[kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain why the Kubernetes default is **allow-all**, and why default-deny matters.
- Write **default-deny** ingress/egress policies and selectively allow traffic.
- Use **pod**, **namespace**, and **IP block** selectors correctly.
- Allow **DNS egress** so default-deny doesn't break name resolution.
- Name the **limits** of vanilla NetworkPolicy (no FQDN, no L7) and what fixes them.

---

## 1. Concept

### The default is wide open

By default, Kubernetes applies **no** network restrictions: any pod can connect to any
other pod, in any namespace, on any port. Namespaces give you *naming* and RBAC
isolation, but **not network isolation** — `team-a`'s pods can reach `team-b`'s
database unless you say otherwise. For a multi-tenant platform that's a serious gap,
and it's exactly the kind of lateral movement an attacker exploits (the zero-trust
concern from [Module 13.8](../../13-security-and-policy-engineering/08-zero-trust-for-platforms/)).

A **NetworkPolicy** is a namespaced resource that selects pods and declares which
traffic is allowed to/from them. The critical behavior:

```text
   A pod with NO NetworkPolicy selecting it     → allow all (the default)
   A pod selected by ANY NetworkPolicy          → DENY everything not explicitly allowed
                                                   (for the policy types listed)
```

So NetworkPolicies are **additive allow-lists that flip the default to deny** for the
pods they select. You don't write "deny" rules; you write a default-deny policy that
selects everything, then add narrow "allow" policies on top.

### Default-deny: start closed

The foundational pattern is a policy that selects **all pods** in a namespace and
allows **nothing** — flipping that namespace to deny-by-default for both directions:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: team-a
spec:
  podSelector: {} # select EVERY pod in the namespace
  policyTypes: [Ingress, Egress]
  # no ingress/egress rules => nothing is allowed
```

With that applied, every pod in `team-a` is now isolated — no traffic in or out until
you explicitly allow it. This is "start closed, open only what's needed," the same
guardrail philosophy as Project 1's Pod Security Admission.

### Selectively allow: the three selectors

You then add policies that allow specific flows. Rules select peers three ways:

- **podSelector** — allow pods with certain labels (e.g. `app: frontend`).
- **namespaceSelector** — allow pods from certain namespaces (e.g. `team: team-a`).
- **ipBlock** — allow a CIDR (for external IPs, with optional `except`).

```yaml
# Allow frontend pods to reach backend pods on 8080 (ingress TO backend)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: team-a
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes: [Ingress]
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: frontend
      ports:
        - protocol: TCP
          port: 8080
```

### The DNS trap (the #1 default-deny gotcha)

Here's what bites everyone: the moment you apply **default-deny egress**, pods can no
longer reach **CoreDNS**, so *every name lookup fails*. The app looks broken in a
baffling way — it can't resolve `backend`, its database, or anything. You must
explicitly allow egress to kube-dns:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress
  namespace: team-a
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

> **Remember this one.** "Default-deny egress broke everything" is almost always
> missing DNS egress. It's the networking equivalent of forgetting `runAsNonRoot`.

### Ingress vs egress

- **Ingress** policies control traffic **coming into** the selected pods.
- **Egress** policies control traffic **leaving** the selected pods.

A policy with `policyTypes: [Ingress, Egress]` but empty rule lists denies both
directions. Many teams start with default-deny **ingress** only (simpler), then add
egress control later for stronger zero-trust posture.

### The limits of vanilla NetworkPolicy

The built-in `networking.k8s.io` NetworkPolicy is **L3/L4 only** and has real gaps:

- **No FQDN/DNS-name rules.** You can allow a CIDR, not `api.stripe.com` — and external
  API IPs change. (Cilium adds DNS-based egress — Module 14.4.)
- **No L7 awareness.** You can allow port 8080, not "GET /api/* but not DELETE".
  (Cilium/Istio add L7 — Modules 14.4/14.6.)
- **Enforced by the CNI, not Kubernetes.** If your CNI doesn't implement
  NetworkPolicy (e.g. Flannel alone), the objects apply but **nothing is enforced** —
  a dangerous false sense of security.

These gaps are precisely why platforms reach for Cilium (next module).

---

## 2. Why it matters for platform engineering

Network isolation is a **platform-owned security control**, and NetworkPolicy is how
you deliver it as a default rather than a hope:

- **Blast-radius containment.** A compromised or buggy workload shouldn't reach the
  whole cluster. Default-deny per namespace contains it — the network complement to
  the RBAC/quota isolation from Projects 1 and 2.
- **Multi-tenancy.** Teams must not accidentally (or maliciously) reach each other's
  workloads. Namespace-scoped default-deny enforces that boundary.
- **Compliance.** "Default-deny with documented, reviewed exceptions" is a baseline
  control in most security frameworks (and the Production Readiness checklist).
- **It's a guardrail you can enforce.** A Kyverno policy (Module 13.3) can *require*
  that every namespace has a default-deny policy — making isolation structural.

## 3. Mental model

```text
   Default (no policy selects a pod):  ALLOW ALL  ── wide open, flat network
                        │  apply a default-deny policy
                        ▼
   Selected by a policy:               DENY ALL   ── except what you allow-list
                        │  add narrow allow policies
                        ▼
   team-a namespace:
     default-deny (ingress+egress)        ← start closed
     allow-dns-egress                     ← or DNS breaks EVERYTHING
     allow-frontend → backend:8080        ← open only the real flows
     allow-egress to the database CIDR    ← and nothing else leaves

   You never write "deny". You write default-deny + explicit allows.
```

One sentence: **NetworkPolicies turn the open-by-default pod network into
deny-by-default-with-allow-lists — and you must allow DNS or everything breaks.**

## 4. Minimal implementation

The smallest meaningful demonstration is two pods and one policy. Prove the flat
network is open, then close it:

```bash
# Before any policy: frontend can reach backend (open by default)
kubectl exec frontend -- curl -s -m 3 http://backend && echo "  <- open"

# Apply default-deny ingress on backend
kubectl apply -f default-deny.yaml

# Now it's blocked (times out) — the flat network is closed for backend
kubectl exec frontend -- curl -s -m 3 http://backend || echo "  <- denied"

# Allow exactly frontend -> backend, and it works again — but ONLY that flow
kubectl apply -f allow-frontend.yaml
kubectl exec frontend -- curl -s -m 3 http://backend && echo "  <- allowed"
```

Three commands take you from open → closed → precisely-open. The lab does this fully,
including the DNS trap, which you'll trigger and fix on purpose.

## 5. Hands-on lab

Lock a namespace to **default-deny**, watch it break (including DNS), then open exactly
the flows that are needed — frontend→backend plus DNS egress — and verify that
everything else stays blocked.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Default-deny every tenant namespace, by policy.** Use Kyverno (Module 13.3) to
  *require* a default-deny NetworkPolicy in every namespace, so a new team is isolated
  automatically — not when someone remembers.
- **Always allow DNS egress** in your default-deny baseline, or you'll ship an outage.
  Bake it into the namespace template.
- **Confirm the CNI actually enforces policy.** Applying NetworkPolicy objects on a
  non-enforcing CNI gives false security. Test with a real denied connection.
- **Egress control needs FQDN in practice.** Vanilla policy only does CIDRs; external
  endpoints change IPs. Plan for Cilium DNS-based egress (Module 14.4) for real
  "allow only these external APIs" rules.
- **Test policies as code.** Policy changes can silently cut traffic. Validate in CI
  (a connectivity test) before rollout; treat them like any other production change.
- **Observe denials.** Without flow visibility (Hubble, Module 14.4), a wrong policy is
  an invisible outage. Log/monitor dropped flows.

## 7. Common mistakes

- **Default-deny egress without allowing DNS.** — Every name lookup fails and the app
  looks mysteriously broken. *Fix:* always include the kube-dns egress allow.
- **Assuming namespaces isolate network traffic.** — They don't; only NetworkPolicy
  does. *Fix:* add default-deny per namespace.
- **Applying policy on a non-enforcing CNI (e.g. Flannel).** — Objects exist, nothing
  is enforced. *Fix:* use a policy-capable CNI and verify a real denial.
- **Writing broad allows that defeat the purpose.** — `from: [{}]` allows everything.
  *Fix:* select specific pods/namespaces and ports.
- **Forgetting policies are namespaced.** — A policy in `team-a` doesn't protect
  `team-b`. *Fix:* apply the baseline to every namespace (templated/enforced).
- **Confusing "no ingress rules" with "allow all ingress".** — An Ingress-type policy
  with no rules **denies** all ingress. *Fix:* understand selected ⇒ deny-by-default.

## 8. Assessment

**Knowledge checks**

1. What happens to a pod's traffic the moment *any* NetworkPolicy selects it?
2. Write (in words) the two policies you need so `team-a` is default-deny but its pods
   can still resolve DNS.
3. What are the three ways a NetworkPolicy rule can select its peers?
4. Name two things vanilla NetworkPolicy **cannot** express.
5. You applied a default-deny policy but nothing is actually blocked. What's the most
   likely cause?

**Concept exercise**

> Explain "default-deny with allow-lists" to a developer **without using the words
> "NetworkPolicy" or "firewall."** Use the idea of a guest list.

**Debugging exercise**

> A team enables default-deny egress and immediately every service in the namespace
> starts failing with timeouts on *all* outbound calls — even to services that should
> be allowed. What's almost certainly wrong, and what's the one policy you'd check
> first?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** For the `policyTypes` it lists, the pod flips to **deny-by-default** —
  everything not explicitly allowed by some policy is dropped.
- **Q2:** (1) a default-deny policy selecting all pods for Ingress+Egress; (2) an
  egress-allow policy permitting UDP/TCP 53 to the kube-dns pods in kube-system.
- **Q3:** `podSelector` (by pod labels), `namespaceSelector` (by namespace labels),
  and `ipBlock` (a CIDR).
- **Q4:** Any two of: FQDN/DNS-name rules, L7 (HTTP method/path) rules — it's L3/L4
  only.
- **Q5:** The CNI doesn't enforce NetworkPolicy (e.g. Flannel alone) — the objects
  apply but nothing acts on them.
- **Debugging:** Default-deny egress blocked DNS, so names don't resolve and *all*
  outbound calls fail (even allowed ones, because they can't resolve their target).
  Check for / add the **kube-dns egress allow** policy first.

</details>

## 9. Further reading

- Kubernetes — [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- Kubernetes — [Declare Network Policy (walkthrough)](https://kubernetes.io/docs/tasks/administer-cluster/declare-network-policy/)
- [kubernetes-network-policy-recipes (ahmetb)](https://github.com/ahmetb/kubernetes-network-policy-recipes) — practical policy examples
- [Cilium Network Policies (L7 + DNS)](https://docs.cilium.io/en/stable/security/policy/) — what fixes the gaps
- [Module 13.8 · Zero Trust for Platforms](../../13-security-and-policy-engineering/08-zero-trust-for-platforms/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [14.2 — CNI Plugins](../02-cni-plugins/) · _Next:_ [14.4 — Cilium and eBPF →](../04-cilium-and-ebpf/)
