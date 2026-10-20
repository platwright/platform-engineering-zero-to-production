# 13 · Security and Policy Engineering

> By now you can build, ship, and operate workloads on Kubernetes. This phase makes
> them **safe by default**. Security is not a gate you bolt on before go-live; it is
> a set of structural properties the platform provides so that every team is secure
> *without having to be a security expert*. You'll move security left and down —
> into the paved road, the admission controller, and the supply chain — so the safe
> way is the easy way.

**Phase 10 · 8 modules · ~14–20 hours**

> Baselines for this phase: the
> [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-10/) and the
> [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes). Keep
> both open — we map lessons and labs back to them throughout.

## Why this phase matters

Every prior phase quietly assumed a trustworthy environment. That assumption does
not survive contact with production. Credentials leak, dependencies get
compromised, images are swapped, a pod gets popped, an over-broad `ClusterRoleBinding`
becomes a cluster takeover. The question is never *"will something go wrong?"* but
*"when it does, how far can it spread?"*

Platform engineering answers that question **structurally**. Instead of asking every
product team to remember to drop capabilities, scan images, rotate secrets, and write
network policies, the platform makes those properties the default — enforced by
machinery, visible in reports, and impossible to forget. That is the difference
between a *checklist* (which decays the moment someone is in a hurry) and a
*guardrail* (which holds regardless).

This phase gives you the defence-in-depth model and the tools to implement it:

- **Own the baseline.** The platform team defines and enforces the security baseline;
  product teams *consume* it. Security becomes a capability, not a committee.
- **Assume breach.** Design as if an attacker is already inside. Least privilege,
  short-lived credentials, segmented networks, and runtime detection limit the blast
  radius of any single failure.
- **Shift security into the paved road.** Admission policy, signed images, and synced
  secrets make the secure path the *default* path — adopted by choice, not decree.
- **Make it provable.** "We think it's locked down" is not security. You'll produce
  evidence: benchmark scores, `auth can-i` tables, policy reports, SBOMs, signatures,
  and audit logs.

You have already met several of these ideas. Module 02.5 hardened the container
(non-root, read-only, dropped capabilities); Module 03.6 introduced RBAC; Project 1
shipped Pod Security Admission and a hardened golden path; Project 2 added a
signed-image Kyverno policy and the External Secrets Operator. This phase deepens all
of them into a coherent, enforced whole.

## Visual references

- [Kubernetes security layers](../diagrams/architecture/kubernetes-Security-Layers.png)
- [RBAC model](../diagrams/platform/rbac-model.png)
- [Supply-chain pipeline](../diagrams/architecture/supply-chain-pipeline.png)
- [Secret management flow](../diagrams/architecture/secret-management-flow.png)

## The seven layers of defence in depth

No single control is sufficient. Real Kubernetes security is a stack of independent
layers, each of which an attacker must defeat and each of which contains the damage
if the layer above it fails:

```text
       ┌─────────────────────────────────────────────────────────────┐
  7 ▸  │  Runtime security        detect & respond (Falco, PSS)        │  Module 65
       ├─────────────────────────────────────────────────────────────┤
  6 ▸  │  Network policies        segment east-west traffic (L3–L7)    │  Module 66 / Phase 11
       ├─────────────────────────────────────────────────────────────┤
  5 ▸  │  Workload security       non-root, drop caps, PSS Restricted  │  Modules 59, 61, 65
       ├─────────────────────────────────────────────────────────────┤
  4 ▸  │  Namespace isolation      RBAC, quotas, least privilege       │  Modules 59, 60
       + RBAC
       ├─────────────────────────────────────────────────────────────┤
  3 ▸  │  Node & OS hardening     CIS node checks, minimal host        │  Module 59
       ├─────────────────────────────────────────────────────────────┤
  2 ▸  │  Cluster API access       authn/authz to the API server       │  Modules 59, 60
       ├─────────────────────────────────────────────────────────────┤
  1 ▸  │  Cloud IAM & perimeter   identity, VPC, firewall, no public   │  Module 59 / Phase 2 IaC
       └─────────────────────────────────────────────────────────────┘
          Assume each layer WILL be breached. The next one limits the blast radius.
```

Supply-chain and secret controls (Modules 62–64) cut *across* these layers: they
decide what is even allowed to run and what it is allowed to know. Zero trust
(Module 66) is the organizing philosophy that ties them together — never trust,
always verify, least privilege everywhere.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 59 | [Security Principles for Platform Teams](./01-security-principles/) | Defence in depth; the platform-owned baseline; CIS Benchmark; OWASP Kubernetes Top 10; assume-breach thinking. | A kube-bench + OWASP self-assessment report for a kind cluster. |
| 60 | [Kubernetes RBAC Deep Dive](./02-kubernetes-rbac-deep-dive/) | Subjects, impersonation, aggregated ClusterRoles, RBAC auditing, JIT access, CI/CD identity. | An RBAC risk audit (jq + `kubectl-who-can`) and a least-privilege CI ServiceAccount. |
| 61 | [Policy as Code with Kyverno](./03-policy-as-code-with-kyverno/) | validate / mutate / generate / verifyImages; ClusterPolicy vs Policy; audit vs enforce; exceptions and reports. | A set of ClusterPolicies that block root, `:latest`, and missing limits/labels. |
| 62 | [Secret Management](./04-secret-management/) | Why Secrets aren't secret; KMS encryption-at-rest; Vault; External Secrets Operator; Workload Identity; rotation. | A Vault + ESO pipeline that syncs and rotates a secret with no app code change. |
| 63 | [Supply Chain Security](./05-supply-chain-security/) | Supply-chain attacks; SLSA levels; SBOMs (Syft); vulnerability scanning (Grype); provenance attestation. | An SBOM, a triaged Grype scan, and a signed SBOM attestation. |
| 64 | [Image Signing and Verification](./06-image-signing-and-verification/) | Why sign; Cosign keyless signing; Rekor transparency log; Kyverno `verifyImages` enforcement. | A keyless-signed image and a Kyverno policy that blocks unsigned images. |
| 65 | [Runtime Security](./07-runtime-security/) | Runtime threat detection; Falco + eBPF; custom rules; Pod Security Standards; seccomp/AppArmor; gVisor/Kata. | A Falco DaemonSet and a custom rule that fires on a shell in a pod. |
| 66 | [Zero Trust for Platforms](./08-zero-trust-for-platforms/) | Zero-trust principles; SPIFFE/SPIRE identity; mTLS; L7 authorization; JIT access; zero standing privileges. | A CiliumNetworkPolicy L7 starter and a zero-trust access design. |

Work them in order — each builds on the last. Together they take you from "what does
secure *mean* on Kubernetes?" to "here is an enforced, provable, defence-in-depth
baseline every team inherits for free."

## Learning objectives

By the end of this phase you will be able to:

- Apply the **seven-layer defence-in-depth model** and reason about blast radius when
  any single layer fails.
- Score a cluster against the **CIS Kubernetes Benchmark** and the **OWASP Kubernetes
  Top 10**, and turn findings into platform work.
- Design and **audit RBAC** for least privilege, and build CI/CD identities that
  cannot escalate.
- Enforce a security baseline with **policy as code** (Kyverno): validate, mutate, and
  verify images, rolling out safely from audit to enforce.
- Manage secrets without committing them to Git — **Vault + ESO + KMS** — including
  rotation and keyless cloud access.
- Secure the **software supply chain** end to end: SBOMs, vulnerability scanning,
  provenance, and signature verification at admission.
- Detect and respond to threats **at runtime** with Falco and Pod Security Standards.
- Describe and start implementing a **zero-trust** architecture: workload identity,
  mTLS, L7 authorization, and zero standing privileges.

## Prerequisites

- [Phase 3 · Kubernetes Fundamentals](../03-kubernetes-fundamentals/) — especially
  [RBAC (03.6)](../03-kubernetes-fundamentals/06-rbac/).
- [Module 02.5 · Container Security](../02-containerization/05-container-security/) —
  the container hardening this phase enforces cluster-wide.
- [Project 1](../04-platform-project-01/) and [Project 2](../09-platform-project-02/) —
  Pod Security Admission, the signed-image Kyverno policy, and ESO appear here as
  first-class topics.
- [Phase 8 · Kubernetes Advanced](../10-kubernetes-advanced/) — admission webhooks, the
  mechanism Kyverno builds on.
- A local toolchain: Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). Labs
  also use Kyverno, Falco, Syft, Grype, Cosign, Vault (dev mode), and ESO — each
  installed in its lab.

## A note on cost

Every lab in this phase runs **free** on a local kind cluster with open-source tools.
Where a step would normally use a cloud KMS, a managed secret manager, or GitHub
OIDC, it is clearly marked **optional** with a cost/accounts note, and a local
equivalent keeps the core exercise free. You never need a cloud account to complete
the required path.

---

Start with [**59 · Security Principles for Platform Teams →**](./01-security-principles/)
