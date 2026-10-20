# Module 13.1 — Security Principles for Platform Teams

> Security on Kubernetes is not a product you buy or a scan you run the day before
> launch. It is a **layered, structural property** the platform provides so that every
> team is secure without having to be a security expert. This module gives you the
> mental model — defence in depth, assume breach, least privilege — and the two
> industry baselines (CIS Benchmark, OWASP Kubernetes Top 10) you'll measure against
> for the rest of the phase.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 02.5 · Container Security](../../02-containerization/05-container-security/),
[Module 03.6 · RBAC](../../03-kubernetes-fundamentals/06-rbac/), and a working
`kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain **defence in depth** as seven independent layers and reason about blast
  radius when any one fails.
- Articulate why the **platform team owns the security baseline** and product teams
  consume it.
- Describe the **CIS Kubernetes Benchmark** and the **OWASP Kubernetes Top 10**, and
  say what each is for.
- Apply **assume-breach** and **least-privilege** thinking to a platform design.
- Score a cluster against a benchmark and turn findings into a prioritized backlog.

---

## 1. Concept

### Security is structural, not a checklist

Every earlier phase assumed a trustworthy environment. Production does not grant that
assumption. A single leaked token, a compromised dependency, or one over-broad
`ClusterRoleBinding` can become a cluster takeover. The honest question is never
*"will something go wrong?"* but *"when it does, how far can it spread?"*

There are two ways to answer that. One is a **checklist**: a wiki page that tells every
team to run as non-root, scan images, drop capabilities, and write network policies.
Checklists decay the instant someone is in a hurry, and they put the security burden
on people who were hired to write business logic. The other is a **guardrail**: the
platform makes those properties the default, enforced by machinery, visible in
reports, impossible to forget. Platform engineering chooses guardrails. Security
becomes a *capability the platform provides*, not a committee you escalate to.

This reframes the platform team's job. You are not the team that *reviews* everyone
else's security; you are the team that makes the secure path the **easy, default**
path — the paved road that ships hardened by construction (Module 02.5), admits only
compliant workloads (Module 13.3), and hands out short-lived credentials (Module
13.4). Teams get security by adopting the golden path, not by remembering a list.

### Defence in depth: seven layers

The layered model is shown in [Kubernetes security layers](../../diagrams/architecture/kubernetes-Security-Layers.png).

No single control is sufficient, because every control can fail. Defence in depth
stacks **independent** layers so that an attacker must defeat each one, and so that a
breach of any layer is *contained* by the next (the layers are drawn top-down in the
[phase overview](../README.md)). Read each boundary as a question: *if the attacker is
already past the layers below, what stops them here, and what do they gain if they
win?*

1. **Cloud IAM & perimeter.** A private control plane and tight cloud IAM make a
   stolen `kubeconfig` useless from the internet (you built this in Phase 2 IaC).
2. **Cluster API access.** Every request is authenticated then authorized; weak authn
   or broad authz (cluster-admin for CI) collapses every layer below it.
3. **Node & OS hardening.** A minimal, patched node with a locked-down kubelet limits
   what a container escape can reach.
4. **Namespace isolation + RBAC.** Least privilege within the tenancy boundary caps the
   blast radius of a stolen ServiceAccount token (Module 13.2).
5. **Workload security.** Non-root, read-only root filesystem, dropped capabilities —
   Module 02.5 applied cluster-wide via Pod Security Standards and policy (13.3).
6. **Network policies.** Default-deny east-west traffic so a compromised pod cannot
   reach every other service (Module 13.6 / Phase 11).
7. **Runtime security.** Assume something still gets through: watch *behaviour* —
   unexpected shells, new binaries, odd connections — and respond (Module 13.7).

Two concerns cut *across* all seven layers: the **supply chain** (Modules 13.5–13.6)
decides what is even allowed to run, and **secret management** (Module 13.4) decides
what a workload is allowed to know. Zero trust (Module 13.8) is the philosophy that
unifies the whole stack.

### Assume breach, least privilege, verify everything

Three principles drive every decision in this phase:

- **Assume breach.** Design as though an attacker already has a foothold. This flips
  the default from "allow unless blocked" to "deny unless explicitly needed," and it
  makes containment — not just prevention — a first-class goal.
- **Least privilege.** Every identity (human, workload, pipeline) gets the minimum
  permissions it needs and nothing more. The cost of a compromised credential is
  bounded by what that credential could do.
- **Verify everything.** Trust is earned per request, not granted by network location.
  Signed images, authenticated service-to-service calls, and audited access replace
  "it's inside the cluster, so it's fine."

### Two baselines: CIS Benchmark and OWASP Kubernetes Top 10

You don't have to invent "what secure means." Two community baselines define it, and
this phase maps to both:

- **CIS Kubernetes Benchmark** — a detailed, prescriptive checklist of configuration
  controls for the control plane, etcd, kubelet, and policies, each with an audit and
  remediation. It answers *"is this cluster configured to a known-good standard?"* and
  tools like **kube-bench** score a cluster against it automatically. Think of it as
  the hardening spec for layers 2–5.
- **OWASP Kubernetes Top 10** — a risk-ranked list of the *most common and impactful*
  ways Kubernetes deployments get compromised. It answers *"what actually goes wrong
  in the real world, and am I exposed?"* Highlights you'll recognize across this phase:

  ```text
  K01  Insecure workload configurations     → Modules 13.3, 13.5 (PSS, policy)
  K02  Supply chain vulnerabilities         → Modules 13.5, 13.6 (SBOM, signing)
  K03  Overly permissive RBAC               → Module 13.2 (RBAC audit)
  K04  Lack of centralized policy enforcement→ Module 13.3 (Kyverno)
  K05  Inadequate logging & monitoring      → Module 13.7 + Phase 11
  K06  Broken authentication                → Modules 13.1, 13.2
  K07  Missing network segmentation controls→ Module 13.6 / 13.8
  K08  Secrets management failures          → Module 13.4
  K09  Misconfigured cluster components      → Module 13.1 (CIS/kube-bench)
  K10  Outdated & vulnerable components      → Module 13.5 (scanning)
  ```

Use the Benchmark to harden configuration and the Top 10 to prioritize *risk*. They
are complementary: one is "are the knobs set correctly," the other is "where does the
damage actually come from."

---

## 2. Why it matters for platform engineering

- **Leverage.** A baseline defined once by the platform team secures the Nth team for
  free. Fixing a class of misconfiguration in the golden path fixes it everywhere —
  something per-team review can never match.
- **Blast-radius math is the job.** When (not if) a credential leaks or a pod is
  popped, the difference between a shrug and an incident is whether the layers below
  contained it. You design for containment on purpose.
- **Audits become evidence, not panic.** When security is structural, compliance is a
  report you generate (benchmark score, policy report, `auth can-i` table), not a fire
  drill — and regulated industries pay a premium for exactly that.
- **It removes a false trade-off.** "Move fast *or* be secure" is a symptom of bolt-on
  security; a paved road hardened by construction lets teams move fast *because* the
  safe path is the easy one. Deferring security "until later" (an anti-pattern this
  course names) just builds a platform teams route around.

---

## 3. Mental model

Hold two pictures in your head.

**1. The castle, not the gate.** Perimeter-only security is a single wall: breach it
and you own everything inside. Defence in depth is a castle — moat, wall, keep,
guards — where each boundary assumes the previous one may have fallen.

```text
Perimeter only (brittle)             Defence in depth (resilient)
────────────────────────             ────────────────────────────
   ┌───────────────┐                  ( ( ( ( ( ( ( ( ( ( ( (
   │   firewall    │  breach → all      moat · wall · keep · guard
   │  EVERYTHING   │  is lost          breach one → the next still
   │   inside is   │                   contains you; no single
   │    trusted    │                   failure is fatal
   └───────────────┘
```

**2. Blast radius is the metric.** For any control, ask two questions: if this layer
is breached, *what can the attacker reach next* (lateral movement) and *what can they
do with it* (privilege)? Security work is shrinking both answers at every layer —
least-privilege RBAC, admission policy, segmented networks, short-lived secrets, signed
images, and runtime detection are each one of those two answers getting smaller.

---

## 4. Minimal implementation

Before any tooling, do the cheapest, highest-leverage security activity there is: a
**five-minute threat model** of a workload, mapped to the seven layers. You are
answering "where could this go wrong, and what contains it?"

Take a typical service — a public API pod that reads a database password from a
Kubernetes Secret and runs as root because nobody changed the default:

```text
Asset: customer API + its database credentials
Threat → which layer should contain it → is it contained today?

  Stolen image pulled from a typo-squatted registry
      → L2 (what's admitted) + supply chain      → NO  (no signing/policy yet)
  Container runs as root, writable filesystem
      → L5 (workload security)                   → NO  (default pod spec)
  Compromised pod reads every other service
      → L6 (network policy)                      → NO  (default-allow networking)
  ServiceAccount token can list Secrets cluster-wide
      → L4 (RBAC)                                → NO  (over-broad default)
  Attacker opens a shell and runs a crypto-miner
      → L7 (runtime detection)                   → NO  (nothing is watching)
```

Five "NO"s, and we haven't installed anything. That list *is* the phase backlog: PSS +
policy (L5), network policy (L6), RBAC audit (L4), signing (supply chain), Falco (L7).
A threat model turns "security" from a vague anxiety into a prioritized to-do list.

Now make it quantitative. The smallest honest "how bad is it?" check is to see how
many `cluster-admin` grants exist — the single most common real-world finding:

```bash
# Who holds the keys to the kingdom? (should be a tiny, known list)
kubectl get clusterrolebindings -o json \
  | jq -r '.items[]
      | select(.roleRef.name=="cluster-admin")
      | .subjects[]? | "\(.kind)/\(.namespace // "-")/\(.name)"'
```

If that prints more than a handful of entries — or any ServiceAccount you don't
recognize — you have found OWASP **K03 (overly permissive RBAC)** in under a minute.
The lab scales this up with **kube-bench** and a full OWASP self-assessment.

---

## 5. Hands-on lab

You'll stand up a kind cluster, score it with **kube-bench** against the CIS
Kubernetes Benchmark, and walk the **OWASP Kubernetes Top 10** as a structured
self-assessment — producing exactly the kind of baseline report a platform team
publishes before it starts enforcing anything.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Benchmarks are a floor, not a ceiling.** Managed control planes (GKE/EKS/AKS)
  already satisfy many control-plane CIS controls — focus on the node, policy, and
  RBAC controls you actually own. A green score is necessary, not sufficient; it says
  nothing about your application logic.
- **Continuous, not one-shot.** Run kube-bench and config scanners (kubescape, Trivy's
  `k8s` mode) on a schedule and in CI, not once before an audit. Yesterday's hardened
  cluster is today's finding after one `kubectl edit`.
- **Own the baseline as code.** Keep it in Git as policies, Terraform, and golden-path
  defaults — reviewable, versioned, rolled out like any product change — not as tribal
  knowledge in a runbook.
- **Prioritize by blast radius, not CVSS count.** One over-broad RBAC grant or an
  exposed dashboard outranks a hundred low-severity base-image findings. Triage by
  "what does this let an attacker *do*" — exactly what the OWASP list encodes.
- **Make shared responsibility explicit.** Write down which layers the cloud, the
  platform, and the product team each own. Most breaches live in the gaps nobody
  thought they owned.
- **Security has SLOs too.** Track mean time to patch a critical CVE, % of workloads on
  the hardened baseline, and % of clusters passing the benchmark. What you don't
  measure, you don't improve.

---

## 7. Common mistakes

- **Perimeter-only security ("we have a firewall").** Treating the network edge as the
  whole defence; once inside, everything is trusted and one breach is total. *Fix:*
  assume breach and build inner layers (RBAC, PSS, network policy, runtime) that each
  contain the one above.
- **Security as a final gate.** A review or scan bolted on right before launch finds
  problems too late to fix cheaply and makes security the team that says "no." *Fix:*
  shift it into the paved road so the default is compliant.
- **Chasing the scanner score.** Driving a CIS/CVE number to green while ignoring an
  over-permissive RBAC model or an exposed Secret. *Fix:* prioritize by blast radius
  (OWASP Top 10), not by list length.
- **The platform mandates but doesn't provide.** Requiring non-root and image scanning
  without giving teams a hardened base image, a policy that enforces it, and docs.
  *Fix:* provide the capability, don't just publish the requirement.
- **Treating the benchmark as done-once.** Passing the audit and never re-checking as
  nodes, versions, and manifests drift. *Fix:* run it continuously in CI and on a
  schedule.
- **No named owner per layer.** Assuming "the cloud handles it" or "the app team
  handles it" with no explicit mapping. *Fix:* a written shared-responsibility matrix.

---

## 8. Assessment

**Knowledge checks**

1. Name the seven layers of defence in depth, and give one control at each.
2. What is the difference in *purpose* between the CIS Kubernetes Benchmark and the
   OWASP Kubernetes Top 10?
3. What does "assume breach" change about how you set defaults?
4. Why does the platform team *owning* the baseline produce more security than
   *reviewing* every team's work?

**Concept exercise**

> Explain defence in depth to a skeptical engineer **without using the words
> "firewall," "scanner," or any product name.** Make the blast-radius argument land.

**Trade-off / debugging exercise**

> A team's kube-bench report is 95% green, yet a penetration test took over the
> cluster in an hour by stealing one CI pipeline's token. Explain how both facts can
> be true at once, which OWASP risk this maps to, and what you'd fix first. Then
> describe how you'd stop the *class* of problem, not just this instance.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Layers:** (1) cloud IAM/perimeter, (2) cluster API access, (3) node/OS hardening,
  (4) namespace isolation + RBAC, (5) workload security/PSS, (6) network policies,
  (7) runtime security — e.g. private endpoint, least-privilege RBAC, patched nodes,
  quotas, non-root containers, default-deny NetworkPolicy, Falco.
- **Purpose:** the Benchmark is a prescriptive *configuration* standard ("are the knobs
  set right?"); the Top 10 is a risk-ranked list of *how breaches actually happen*
  ("where's the real exposure?"). Use the first to harden, the second to prioritize.
- **Assume breach:** you default to deny, minimize privilege, segment the network, and
  invest in containment and detection — not just prevention — because you plan for the
  attacker already being inside.
- **Own vs review:** fixing the golden path once secures every current and future team
  structurally; review is per-change, doesn't scale, becomes a bottleneck, and relies
  on humans remembering under deadline pressure.
- **Trade-off:** a green benchmark measures *configuration*, not the *RBAC/identity*
  blast radius. The CI token had far too much power — OWASP **K03 (overly permissive
  RBAC)**, amplified by weak **K06 (authentication)**. Fix first: scope the CI
  ServiceAccount to least privilege and rotate the token (Module 13.2). Stop the class:
  make least-privilege CI identity a template/policy so no pipeline can be granted
  cluster-admin, and audit RBAC continuously.

</details>

---

## 9. Further reading

- OWASP — [Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-10/)
- CIS — [Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- Aqua Security — [kube-bench](https://github.com/aquasecurity/kube-bench)
- Kubernetes — [Security overview and checklist](https://kubernetes.io/docs/concepts/security/security-checklist/)
- NSA/CISA — [Kubernetes Hardening Guide](https://media.defense.gov/2022/Aug/29/2003066362/-1/-1/0/CTR_KUBERNETES_HARDENING_GUIDANCE_1.2_20220829.PDF)
- Kubernetes — [The 4C's of Cloud Native security](https://kubernetes.io/docs/concepts/security/overview/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 10 overview](../README.md)
· _Next:_ [Module 13.2 — Kubernetes RBAC Deep Dive →](../02-kubernetes-rbac-deep-dive/)
