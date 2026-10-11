# Module 13.8 — Zero Trust for Platforms

> The seven defence-in-depth layers all point at one idea: stop trusting the network.
> "Inside the cluster" is not a credential. **Zero trust** says every request — human or
> workload — must prove *who it is* and *that it's allowed*, every time, regardless of
> where it comes from. This capstone module ties the phase together: workload identity,
> mutual TLS, identity-based authorization, and the elimination of standing privilege.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 13.1 · Security Principles](../01-security-principles/),
[Module 13.2 · RBAC Deep Dive](../02-kubernetes-rbac-deep-dive/), and a working
`kubectl` + [kind](https://kind.sigs.k8s.io/) (the lab adds Cilium).

## Learning objectives

By the end of this module you will be able to:

- State the three zero-trust principles and contrast them with perimeter security.
- Explain **workload identity** (SPIFFE/SPIRE) and why services need cryptographic IDs.
- Describe how **mTLS** authenticates and encrypts every service-to-service call.
- Write an **identity-based L7 authorization** policy (only `frontend` may `GET` on
  `backend`).
- Design **just-in-time access** and **zero standing privileges** for human operators.

## 1. Concept

### Never trust, always verify, assume breach

Traditional security is a hard shell around a soft interior: get past the firewall and
you're "inside," where services trust each other because they share a network. That
model dies the moment one pod is compromised — the attacker inherits all that implicit
trust and moves laterally at will (the blast-radius problem from Module 13.1).

Zero trust deletes the concept of a trusted interior. Three principles:

- **Never trust.** Network location grants nothing. A request from the next pod gets no
  more trust than one from the public internet.
- **Always verify.** Every request is authenticated (*who are you?*) and authorized
  (*are you allowed to do this specific thing?*) — per request, on identity, not IP.
- **Assume breach.** Design as if the attacker is already inside. Minimize what any
  single identity can reach and do, so one compromise stays small.

The shift is from **where you are** to **who you are**. Identity — not a subnet —
becomes the control plane.

### Workload identity: SPIFFE and SPIRE

Humans have identities (Module 13.2). Workloads need them too — and "the IP it came
from" is not an identity (IPs are reused, spoofable, and reassigned constantly). You
need a **cryptographic, verifiable** identity per workload.

- **SPIFFE** (Secure Production Identity Framework For Everyone) is the open *standard*.
  It defines a **SPIFFE ID** — a URI like `spiffe://cluster.local/ns/payments/sa/api` —
  and the **SVID**, an identity document (usually an X.509 certificate) that encodes it.
- **SPIRE** is the reference *implementation*: a server + per-node agents that
  **attest** workloads (prove a pod really is what it claims, using kubelet/node facts)
  and issue short-lived SVIDs automatically. No secrets to distribute; identities rotate
  on their own.

```text
  Pod starts ──▶ SPIRE agent attests it (node + k8s facts: "this really is payments/api")
                      │
                      ▼
            issues a short-lived SVID (X.509 cert carrying spiffe://.../payments/api)
                      │
                      ▼
   Pod presents its SVID on every call ──▶ peer verifies identity cryptographically
```

The payoff: a workload identity you can *verify*, scope policy to, and rotate — the
foundation everything else in zero trust builds on.

### mTLS: authenticate and encrypt every hop

Ordinary TLS authenticates the *server* (your browser checks the website). **Mutual
TLS** authenticates *both* ends: client and server each present a certificate and
verify the other. Wire SVIDs into mTLS and every service-to-service call becomes:

- **authenticated** — both sides cryptographically prove their SPIFFE identity, and
- **encrypted** — traffic is confidential and tamper-evident on the wire.

Now "is this caller allowed?" is answered by *verified identity*, not by a source IP a
compromised neighbour could borrow. A service mesh (Istio, Linkerd) can provide this via
sidecars; **Cilium** can provide mTLS and identity-aware policy at the eBPF/network
layer without a sidecar per pod — the same Cilium Project 1 chose in
[ADR-002](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-002-why-cilium.md).

### Identity-based authorization: L3/L4 vs L7

Authentication establishes identity; **authorization** decides what that identity may
do. Kubernetes `NetworkPolicy` works at **L3/L4** — it allows or denies by pod selector
and port ("`frontend` pods may reach `backend` on 8080"). Useful, but coarse: once
allowed on the port, the caller can hit *any* path or method.

**L7 authorization** goes further — it understands the application protocol (HTTP, gRPC,
Kafka) and can allow *specific methods and paths*: "`frontend` may `GET /api/*` on
`backend`, and nothing else." That's the zero-trust ideal of **least privilege applied
to traffic**, and it's what `CiliumNetworkPolicy` expresses:

```text
  L3/L4 (NetworkPolicy):   frontend ─▶ backend:8080            (all paths/methods)
  L7   (CiliumNetworkPolicy): frontend ─▶ backend GET /api/*   (this verb, this path)
                                         everything else ─▶ DENIED
```

Start every namespace at **default-deny** and allow only the specific identity-to-
identity calls each service actually needs. Deny-by-default east-west traffic is the
single highest-value zero-trust move.

### JIT access and zero standing privileges

Zero trust applies to humans too. **Standing privilege** — a person who holds
`cluster-admin` permanently — is a permanent, high-value target: one phished laptop and
the attacker has the cluster (recall the debugging exercise in Module 13.1).

- **Zero standing privileges (ZSP).** *No human* holds powerful permissions by default.
  The baseline for everyone is least privilege (Module 13.2).
- **Just-in-time (JIT) access.** When an operator genuinely needs elevation, they
  **request** it; after approval they get a **time-boxed, audited** grant that expires
  automatically (minutes to hours), ideally with a reason and a ticket. Break-glass
  paths exist but are loud and logged.

The result: powerful privilege exists only transiently, for a named person, for a
stated reason, with an audit trail — not as a permanent liability sitting in a binding.

## 2. Why it matters for platform engineering

- **It caps lateral movement — the thing that turns an incident into a catastrophe.**
  Default-deny + identity-based authz means a compromised pod can reach only the few
  identities it was explicitly allowed to, not the whole cluster.
- **Identity-based policy is stable; IP-based policy rots.** Pods churn and IPs recycle
  constantly. Policies written against *identities* survive rescheduling and scaling;
  policies written against IPs are wrong by lunchtime.
- **The platform provides it so teams get it for free.** Workload identity, mTLS, and
  default-deny templates are platform capabilities. Teams inherit authenticated,
  encrypted, least-privilege networking without writing any of it — security as a
  structural default, the course's through-line.
- **ZSP shrinks the human attack surface to near zero.** Most serious breaches ride a
  stolen human credential. If that credential is normally powerless and elevation is
  transient and audited, the stolen-credential play largely stops working.
- **It is the organizing frame for the whole phase.** RBAC (13.2), policy (13.3),
  secrets (13.4), signing (13.6), and runtime (13.7) are all instances of "verify
  explicitly, least privilege, assume breach." Zero trust is the name for the pattern.

## 3. Mental model

**Nightclub, not neighbourhood.** Perimeter security is a gated neighbourhood: clear the
gate once and every house trusts you. Zero trust is a nightclub where the bouncer checks
ID at *every* door — the entrance, the bar, the VIP room — and your wristband only opens
the specific doors you're entitled to, for as long as it's valid.

```text
  Perimeter trust                        Zero trust
  ───────────────                        ──────────
  ┌─────────────────────────┐            every hop re-verifies IDENTITY + checks AUTHZ:
  │ gate │ inside, all pods  │
  │      │ trust each other  │   frontend ──(mTLS: prove spiffe://…/frontend)──▶ backend
  │      │ (flat, implicit)  │              backend: "is frontend allowed GET /api/*? yes" ✓
  └─────────────────────────┘              anyone else / other path ─────────────────▶ ✗
   one breach ⇒ whole interior            one breach ⇒ only its explicitly-allowed calls
```

Two things to remember: **identity is the perimeter now**, and **default-deny is the
starting point** — you add specific allowed identity-to-identity calls, never "allow
all then block some."

## 4. Minimal implementation

You don't need SPIRE and a mesh to start practising zero trust. The smallest move is
**default-deny east-west traffic**, then allow only what's needed. On a plain cluster,
every pod can talk to every other pod:

```bash
# Before: anything can reach anything (implicit trust).
kubectl exec frontend -- curl -s backend:8080/admin   # works — no one checked
```

Apply a default-deny policy for the namespace, and that implicit trust vanishes:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
spec:
  podSelector: {}            # every pod in the namespace
  policyTypes: [Ingress, Egress]
  # no ingress/egress rules = deny all; add back only what each service needs
```

Now nothing talks to anything until you *explicitly* allow it — the zero-trust default.
That's L3/L4. The lab goes one level further with Cilium, authorizing a *specific HTTP
method and path* by *identity*: `frontend` may `GET /api/*` on `backend`, and every
other call — including `frontend` hitting `/admin` — is denied at L7.

## 5. Hands-on lab

You'll stand up a Cilium-enabled kind cluster, deploy a `frontend` and `backend`, and
write a `CiliumNetworkPolicy` that authorizes **only** `frontend → backend GET /api/*`
— proving at L7 that an allowed caller on a forbidden path is still denied.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Roll out default-deny carefully.** Flipping a namespace to deny-all without mapping
  real dependencies causes outages. Observe flows first (Hubble, flow logs), write the
  allow-rules, *then* deny — the same audit-before-enforce discipline as Module 13.3.
- **Identity infrastructure is now critical.** SPIRE/mesh control planes issuing SVIDs
  must be HA; if identity issuance stalls, mTLS handshakes fail. Monitor certificate
  rotation and clock skew.
- **mTLS has cost.** Handshakes and encryption add latency and CPU. eBPF-based (Cilium)
  or sidecar (Istio/Linkerd) approaches trade off overhead, operability, and features —
  choose deliberately, and measure.
- **L7 policy needs a capable data plane.** L7 rules require Cilium (or a mesh); plain
  `NetworkPolicy` is L3/L4 only. Know what your CNI supports before you promise L7.
- **JIT needs tooling and culture.** Time-boxed elevation requires an access-request
  system, approvals, and audit; break-glass must be rare, loud, and reviewed. Without
  the workflow, ZSP becomes "everyone keeps a backdoor admin."
- **Zero trust is a journey, not a switch.** Sequence it: default-deny L3/L4 → workload
  identity + mTLS → L7 authz → ZSP/JIT. Each step is valuable on its own.

## 7. Common mistakes

- **Trusting the network ("it's internal, so it's safe").** Flat, implicit intra-cluster
  trust lets one compromised pod roam freely. *Fix:* default-deny east-west and require
  identity on every call.
- **Authorizing by IP/CIDR.** Pod IPs churn; IP-based allowlists are instantly stale and
  a false sense of safety. *Fix:* write policy against workload *identity* (labels/
  SPIFFE), not addresses.
- **Enabling default-deny blind.** Turning on deny-all without first mapping real traffic
  takes down half the namespace. *Fix:* observe flows, write allows, then deny.
- **Stopping at L3/L4.** Allowing `frontend → backend:8080` and assuming you're done —
  the caller can still hit `/admin`. *Fix:* add L7 authz for the specific methods/paths.
- **Permanent cluster-admins "for convenience."** Standing privilege is a standing
  breach waiting to happen. *Fix:* zero standing privileges + JIT, time-boxed and
  audited.
- **Treating zero trust as a product you buy.** Installing a mesh and declaring victory
  while RBAC is wide open and secrets sit in Git. *Fix:* it's a principle applied across
  every layer of this phase, not a single tool.

## 8. Assessment

**Knowledge checks**

1. State the three zero-trust principles and what each changes about a default.
2. Why is a pod's IP address not a usable identity, and what does SPIFFE provide instead?
3. What does mTLS add over ordinary (server-only) TLS?
4. Give one thing an L7 policy can express that an L3/L4 `NetworkPolicy` cannot.

**Concept exercise**

> Explain how a platform stops a compromised pod from reaching every other service
> **without using the words "zero trust," "mTLS," or "Cilium."** Describe the default
> and the check, not the products.

**Trade-off / debugging exercise**

> A team enables default-deny on their namespace on Friday afternoon. Monitoring breaks,
> then the payments service starts erroring. Explain what almost certainly happened, the
> correct sequence they should have followed, and how workload *identity* (not IP rules)
> would make the eventual allow-list more durable. Then describe how you'd grant an
> on-call engineer temporary debug access without giving anyone standing cluster-admin.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Principles:** never trust (location grants nothing), always verify (authn+authz per
  request on identity), assume breach (minimize reach/privilege so one compromise stays
  small).
- **IP vs SPIFFE:** pod IPs are reused, reassigned, and spoofable, so they identify
  nothing durably. SPIFFE gives a verifiable, cryptographic workload identity (a SPIFFE
  ID in an SVID cert) that policy can target and that rotates automatically.
- **mTLS:** both client and server present and verify certificates, so each call is
  mutually authenticated *and* encrypted — vs server-only TLS where the client is
  unauthenticated.
- **L7 vs L3/L4:** L7 can allow a specific method/path (e.g. `GET /api/*`) or gRPC/Kafka
  verb; L3/L4 can only allow a pod-to-pod connection on a port.
- **Debugging:** default-deny with no egress/ingress allow-rules blocked the monitoring
  scrape and the payments dependency. Correct order: observe real flows (Hubble/flow
  logs) → write identity-based allow policies (including to monitoring) → then enforce
  deny. Identity-based rules survive pod churn that would break IP-based ones. For the
  on-call: a JIT, time-boxed, audited RoleBinding granting only the needed debug verbs,
  auto-expiring — never a permanent cluster-admin.

</details>

## 9. Further reading

- [SPIFFE](https://spiffe.io/) and [SPIRE](https://spiffe.io/docs/latest/spire-about/spire-concepts/)
- Cilium — [Network Policy (L3/L4/L7)](https://docs.cilium.io/en/stable/security/policy/) and [mutual authentication](https://docs.cilium.io/en/stable/network/servicemesh/mutual-authentication/mutual-authentication/)
- NIST — [SP 800-207: Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final)
- Kubernetes — [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- Google — [BeyondProd: cloud-native security model](https://cloud.google.com/docs/security/beyondprod)
- CNCF — [Zero Trust and workload identity (TAG Security)](https://tag-security.cncf.io/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.7 — Runtime Security](../07-runtime-security/)
· _Next:_ [Phase 11 — Kubernetes Networking →](../../14-kubernetes-networking/)
