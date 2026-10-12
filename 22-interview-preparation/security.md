# Interview Prep — Security

> This domain tests whether security is **structural** in your platform — baked
> into the paved road — not bolted on later. Interviewers probe Pod Security
> Standards, RBAC least privilege, admission policy, secrets, and supply chain.
> Practice explaining each control *and the threat it mitigates* out loud, then
> check the model answer.

## Workload and cluster hardening

### Q: What are Pod Security Standards?

**What they're really asking:** Do you know the built-in workload hardening baseline?

Pod Security Standards (PSS) are three cumulative profiles enforced by the built-in
**Pod Security Admission** at the namespace level:

- **Privileged** — unrestricted (for trusted infrastructure workloads only).
- **Baseline** — blocks known privilege escalations: no `privileged`, no host namespaces, limited capabilities.
- **Restricted** — hardened best practice: run as non-root, drop **all** capabilities, `seccomp: RuntimeDefault`, no privilege escalation.

They apply per namespace in `enforce`, `audit`, or `warn` modes, and replaced the
removed PodSecurityPolicy. For custom or cross-cutting rules, layer a policy engine
(Kyverno) on top.

**Going deeper:** [13.1 · Security Principles](../13-security-and-policy-engineering/01-security-principles/) and [02.5 · Container Security](../02-containerization/05-container-security/)

**Red flags:** Running everything `privileged`, or not knowing PodSecurityPolicy was removed in 1.25.

### Q: What is the principle of least privilege in Kubernetes?

**What they're really asking:** Can you apply least privilege concretely through RBAC?

Grant the **minimum verbs on the minimum resources in the minimum scope**. In
practice:

- Prefer namespaced **Roles** over **ClusterRoles**; avoid `cluster-admin` and wildcard (`*`) verbs or resources.
- Give each workload its **own ServiceAccount** with only what it needs, and do not auto-mount the default token where it is not required.
- Bind specific subjects, not broad groups, and audit with `kubectl auth can-i`.

The goal is to shrink the blast radius of any single compromised token.

**Going deeper:** [13.2 · Kubernetes RBAC Deep Dive](../13-security-and-policy-engineering/02-kubernetes-rbac-deep-dive/) and [03.6 · RBAC](../03-kubernetes-fundamentals/06-rbac/)

**Red flags:** Binding `cluster-admin` "to keep things simple," or every pod sharing the default ServiceAccount.

### Q: How does admission control enforce security, and how does Kyverno work?

**What they're really asking:** Do you understand guardrails at the API boundary?

Admission controllers intercept API requests **after** authentication and
authorization but **before** the object is persisted. **Mutating** webhooks can modify
objects (inject defaults, labels, sidecars); **validating** webhooks accept or reject
them. **Kyverno** is a policy engine that runs as an admission webhook and expresses
policies as **Kubernetes resources (YAML, no new language)**. It can:

- **Validate** — reject non-compliant resources (no `latest` tag, resource limits required, must run non-root).
- **Mutate** — add safe defaults (securityContext, labels).
- **Generate** — create resources such as a default-deny NetworkPolicy per new namespace.
- **Verify images** — check signatures before admission.

OPA/Gatekeeper is the Rego-based alternative. Together these turn guardrails into code.

**Going deeper:** [13.3 · Policy as Code with Kyverno](../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/)

**Red flags:** Relying only on code review for policy, or writing policies no one can audit.

## Secrets and identity

### Q: How do you manage secrets in Kubernetes without putting them in Git?

**What they're really asking:** Do you keep cleartext out of the repo and control runtime access?

Keep the real secret in a dedicated manager and deliver it at runtime:

- **External Secrets Operator** — syncs values from Vault or a cloud secrets manager into Kubernetes Secrets from a reference in Git.
- **Sealed Secrets** — encrypt with the cluster's public key so the sealed blob is safe to commit; a controller decrypts in-cluster.
- **SOPS** (age/KMS) — encrypt values in Git, decrypt at apply time.
- **CSI Secrets Store** — mount secrets straight from the external store so nothing lands in etcd.

**Going deeper:** [13.4 · Secret Management](../13-security-and-policy-engineering/04-secret-management/) and [08.5 · Secrets in GitOps](../08-gitops/05-secrets-in-gitops/)

### Q: Are Kubernetes Secrets actually secret?

**What they're really asking:** Do you know the default is encoding, not encryption?

By default a Secret is only **base64-encoded** and stored in etcd — not encrypted.
Anyone with `get` on Secrets, or access to etcd, can read it. Harden it: enable
**encryption at rest** (ideally KMS-backed), apply tight **RBAC** on Secrets, avoid
exposing them as environment variables (prefer mounted files), use an **external
manager**, and rotate regularly.

**Going deeper:** [13.4 · Secret Management](../13-security-and-policy-engineering/04-secret-management/)

**Red flags:** "Secrets are encrypted by default." Confusing base64 with encryption.

### Q: What is zero trust and workload identity for platforms?

**What they're really asking:** Do you understand identity-based, assume-breach security?

Zero trust means trust is **never** granted based on network location — every request
is authenticated and authorized with strong identity, least privilege, and an
assume-breach posture. On platforms this means giving each workload a cryptographic
**identity** (SPIFFE/SPIRE, or cloud workload identity such as IRSA) instead of static
keys, enforcing **mTLS** between services, issuing **short-lived credentials**, and
applying policy at every hop (NetworkPolicy plus authorization). In CI, federate with
**OIDC** to the cloud rather than storing long-lived keys.

**Going deeper:** [13.8 · Zero Trust for Platforms](../13-security-and-policy-engineering/08-zero-trust-for-platforms/)

## Supply chain and runtime

### Q: What is supply chain security?

**What they're really asking:** Do you secure everything that goes into software before runtime?

Supply chain security protects the **path from source to running artifact** — source
code, dependencies, build system, and images — against tampering (think SolarWinds and
the xz backdoor). Core controls:

- Pin and **verify dependencies**; generate an **SBOM** (component inventory).
- Produce **build provenance/attestations** (SLSA) describing how and where an artifact was built.
- **Sign** artifacts and **scan** images; **verify signatures at admission**.
- Protect CI itself with least privilege and OIDC, and use trusted base images.

**Going deeper:** [13.5 · Supply Chain Security](../13-security-and-policy-engineering/05-supply-chain-security/)

### Q: What is image signing and verification?

**What they're really asking:** Do you know cosign/Sigstore, SBOM, and provenance?

**Signing** attaches a cryptographic signature to an image (and its SBOM and
attestations) with **cosign/Sigstore**, so consumers can verify origin and integrity;
keyless signing binds the signature to an **OIDC identity** recorded in a transparency
log (Rekor). You then **verify at admission** (Kyverno or the Sigstore policy
controller) so only signed images from trusted builders run. An **SBOM** tells you
*what is inside*; a **provenance/SLSA attestation** tells you *how it was built*.
Together they give "known contents, not tampered with."

**Going deeper:** [13.6 · Image Signing and Verification](../13-security-and-policy-engineering/06-image-signing-and-verification/)

**Red flags:** Signing images but never verifying them at admission.

### Q: What is runtime security, and how does it differ from admission policy?

**What they're really asking:** Do you know you need detection *after* a pod starts?

Admission policy is **pre-run**: it stops bad configuration from being admitted.
**Runtime security** watches workloads **while they run** and detects malicious
behavior — a shell spawned in a container, unexpected outbound connections, writes to
sensitive paths — typically via **eBPF/syscalls** (for example, Falco). You need both:
admission prevents insecure *config*, runtime catches *compromise* of an
otherwise-valid workload (zero-days, exploited vulnerabilities).

**Going deeper:** [13.7 · Runtime Security](../13-security-and-policy-engineering/07-runtime-security/)

### Q: What does defense in depth look like for a Kubernetes platform?

**What they're really asking:** Can you assemble layered controls rather than trust one?

Layer controls so no single failure is fatal:

- Hardened, **non-root, minimal** images that are **signed and verified**.
- **Restricted** Pod Security plus **Kyverno** guardrails.
- **RBAC least privilege** and per-workload ServiceAccounts.
- **Default-deny NetworkPolicy**, opening only required flows.
- **Encrypted, externally managed secrets** and short-lived credentials.
- **Runtime detection** and **audit logging** for what gets through.

**Going deeper:** [13.1 · Security Principles](../13-security-and-policy-engineering/01-security-principles/) and [14.3 · Network Policies](../14-kubernetes-networking/03-network-policies/)

**Red flags:** Trusting a single control (a scanner, or a firewall) as "the security."
