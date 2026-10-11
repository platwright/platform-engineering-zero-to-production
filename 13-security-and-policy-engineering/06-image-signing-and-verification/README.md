# Module 13.6 — Image Signing and Verification

> You scanned and attested your image in Module 13.5. But how does the *cluster* know
> the image it's about to run is the one your pipeline actually built — and not a
> look-alike an attacker pushed to the registry? **Signing** proves authorship and
> integrity; **verification at admission** refuses anything unsigned. This module uses
> Cosign to sign and Kyverno `verifyImages` to enforce — finishing the supply-chain
> guardrail Project 2 started in its Pass-2 policy.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 13.3 · Policy as Code with Kyverno](../03-policy-as-code-with-kyverno/),
[Module 13.5 · Supply Chain Security](../05-supply-chain-security/), Docker, and a
working `kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain what a signature proves and what it does **not**.
- Sign a container image with **Cosign**, using both key-pair and **keyless** flows.
- Describe the role of **Fulcio** (certificates) and **Rekor** (transparency log) in
  keyless signing.
- Enforce "only signed images run" with a Kyverno **`verifyImages`** policy.
- Pin verification to a specific signer **identity**, not just "any signature."

---

## 1. Concept

### What signing proves

Module 13.5 answered "what's inside this image?" (SBOM) and "is it vulnerable?"
(scanning). Signing answers a different, equally critical question: **"did the party I
trust actually produce this exact artifact, and has it been tampered with since?"**

A registry tag like `myapp:1.4.0` is just a mutable pointer. Anyone with push access —
or anyone who compromises the registry, or wins a typosquat — can make that tag point
at a different image. Pulling by tag is trusting a label. A **signature** binds a
cryptographic identity to an **immutable digest** (`sha256:…`), so verification can
assert two things at once:

- **Integrity** — the bytes are exactly what was signed; a single changed layer breaks
  the signature.
- **Provenance / authenticity** — a specific, named identity signed it (your CI
  pipeline, a release key), not "someone."

What it does **not** prove: that the image is *safe*. A signed image can still be
vulnerable or malicious — signing proves *who* and *what*, not *good*. That's why
signing complements scanning and attestation; it doesn't replace them.

### Sigstore and Cosign

**Sigstore** is the open-source project that made signing practical for the cloud-
native world; **Cosign** is its container-signing tool. Cosign stores signatures as
OCI artifacts *alongside the image in the same registry*, so there is no separate
signature database to run. Two signing models matter:

- **Key-pair signing.** You generate a private/public key pair; CI signs with the
  private key, verifiers trust the public key. Simple and offline-friendly, but you
  now own a **long-lived private key** — it must be stored, rotated, and never leaked.
  Key management is the hard, failure-prone part.
- **Keyless signing.** No long-lived key at all. This is the recommended model.

### Keyless signing: Fulcio + Rekor

Keyless signing replaces "a key you keep" with "an identity you already have":

```text
  CI job needs to sign an image
        │
        ▼
  1. Prove identity via OIDC  ──►  (GitHub Actions / cloud SA issues a short-lived token)
        │
        ▼
  2. Fulcio (CA) issues a SHORT-LIVED certificate bound to that identity
        │
        ▼
  3. Sign the image digest with the ephemeral key; the key is then thrown away
        │
        ▼
  4. Rekor (transparency log) records the signature immutably & publicly
        │
        ▼
     Verifier later checks: valid cert chain + identity matches + logged in Rekor
```

- **OIDC identity.** The signer authenticates as a workload identity — e.g. a GitHub
  Actions workflow (`https://github.com/org/repo/.github/workflows/build.yaml@refs/heads/main`)
  or a cloud service account — issued by an OIDC provider
  (`https://token.actions.githubusercontent.com`).
- **Fulcio** is a certificate authority that issues an **ephemeral** signing
  certificate tied to that identity, valid for minutes. There is no private key to
  store, rotate, or steal — the biggest operational win.
- **Rekor** is an append-only, public **transparency log**. Every signature is
  recorded, so you get an auditable "this identity signed this digest at this time"
  history that an attacker cannot quietly erase.

The payoff: signatures are tied to *verifiable CI identities*, and there are no keys to
leak. The cost: verification depends on the identity model and (for public keyless)
Sigstore's public-good infrastructure — in production many teams run their own.

### Verifying: `cosign verify`

Verification re-checks the chain. The crucial point is that you **pin the identity** —
otherwise you only prove "*somebody* signed it," which a determined attacker can also
do:

```bash
cosign verify \
  --certificate-identity "https://github.com/org/repo/.github/workflows/build.yaml@refs/heads/main" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/org/myapp:1.4.0
```

A signature from the wrong identity, the wrong issuer, or a tampered image all fail.

### Enforcing at admission: Kyverno `verifyImages`

A signature nobody checks is theatre. The platform makes verification **structural** by
checking it at admission — the same guardrail pattern as Module 13.3. Kyverno's
`verifyImages` rule verifies signatures (and attestations) *before* a pod is allowed to
run, and — importantly — **mutates the image reference to its digest** so what runs is
exactly what was verified (no tag-swap race):

```yaml
verifyImages:
  - imageReferences:
      - "ghcr.io/org/*"
    mutateDigest: true
    required: true
    attestors:
      - entries:
          - keyless:
              issuer: "https://token.actions.githubusercontent.com"
              subject: "https://github.com/org/*"
```

This is exactly the policy
[Project 2 shipped in its Pass-2 set](../../09-platform-project-02/gitops-platform/config-repo/platform/pass2/kyverno-verify-images.yaml):
only keyless-signed images from the allowed registry and identity may run; everything
else is rejected. This module is where that policy's machinery finally makes sense.

### Signature policies: who may sign what

Verification is only as strong as the identities you allow. A mature policy constrains
**which identities may sign for which registry paths** — e.g. only the `payments`
pipeline identity may sign `ghcr.io/org/payments/*`. That prevents a compromised
low-value pipeline from signing a high-value image. "Require a signature" is the floor;
"require *this signer's* signature for *this path*" is the real control.

---

## 2. Why it matters for platform engineering

- **It closes the supply chain.** Scanning (13.5) finds known-bad; signing +
  verification guarantees *origin*. Together they mean only artifacts your pipeline
  built, from inputs you controlled, can run — the structural answer to OWASP K02.
- **Keyless removes the worst footgun.** Long-lived signing keys are a classic leaked
  credential. Tying signatures to ephemeral, OIDC-based CI identities deletes an entire
  class of incidents.
- **Enforcement belongs in the platform, not the team.** Individual teams signing by
  convention is hope. One `verifyImages` ClusterPolicy makes "unsigned can't run" true
  for everyone, including images pulled by a compromised manifest.
- **Digest pinning kills the tag-swap race.** Verifying then mutating to the digest
  means the verified bytes are the bytes that run — tags can't be swapped between
  check and pull.
- **It produces audit evidence.** Rekor plus policy reports give you a provable chain:
  this identity built and signed this digest, and the cluster enforced it.

---

## 3. Mental model

A signed image is a **tamper-evident, notarized package**. The signature is the wax
seal (break it and everyone can tell); Fulcio is the notary that vouches for *who*
sealed it; Rekor is the public ledger recording that the sealing happened; and the
admission policy is the loading-dock guard who refuses any package whose seal doesn't
match the approved sender:

```text
  BUILD ──▶ sign (seal + notarized identity) ──▶ Rekor (public ledger)
                                                      │
  registry: image@sha256:… + its signature            │
                                                      ▼
  DEPLOY ──▶ admission: Kyverno verifyImages ──┬─ seal valid AND identity allowed ─▶ run (pinned to digest)
                                               └─ missing / wrong identity / tampered ─▶ REJECTED
```

Remember two things: **pin the identity, not just "signed,"** and **verify where it's
enforced (admission), not where it's convenient (a doc).**

---

## 4. Minimal implementation

First, prove the gap. By default a cluster will happily run *any* image a registry
hands it — signed, unsigned, swapped, doesn't matter. There is no notion of "who made
this."

Now the smallest end-to-end proof of signing, using a local key pair (no accounts):

```bash
cosign generate-key-pair                      # creates cosign.key + cosign.pub
cosign sign --key cosign.key "$IMG"           # $IMG is an image pushed by digest
cosign verify --key cosign.pub "$IMG"         # ✅ prints the verified signature

# Tamper check: verifying a DIFFERENT, unsigned image fails outright:
cosign verify --key cosign.pub nginx:latest   # ❌ no matching signatures
```

That `verify` is the whole idea: a cryptographic yes/no on "did the holder of this key
sign exactly these bytes?" The lab turns that yes/no into an **admission guarantee** —
a Kyverno `verifyImages` policy so the cluster runs the signed image and rejects the
unsigned one, exactly as Project 2's Pass-2 policy does with keyless identities.

---

## 5. Hands-on lab

You'll sign a container image with Cosign, verify it, then apply a Kyverno
`verifyImages` policy so the cluster **only runs the signed image** and rejects an
unsigned one — the local, free version of Project 2's Pass-2 enforcement.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Prefer keyless; if you use keys, treat them like crown jewels.** Keyless ties
  trust to CI identity and removes key storage. If a key pair is unavoidable, keep the
  private key in a KMS/HSM, rotate it, and scope its use tightly.
- **Always pin identity and issuer.** `required: true` with no identity constraint only
  proves "signed by someone." Constrain `subject`/`issuer` (and registry path) so only
  your pipeline's signature counts.
- **Plan for Rekor/Fulcio availability.** Verification reaches the transparency log and
  CA. For production, run your **own** Sigstore stack (or use a vendor's) rather than
  depending solely on the public-good instances, and cache/mirror as needed.
- **Mind `failurePolicy` again.** If the verification webhook is down and policy is
  `Fail`, deploys stop; if `Ignore`, unsigned images slip through. Make Kyverno HA and
  choose deliberately (Module 13.3).
- **Verify attestations, not just signatures.** `verifyImages` can also require a valid
  SBOM/provenance attestation (from Module 13.5), so admission checks *what* was built
  and *how*, not only *who* signed.
- **Roll out in audit first.** Like any policy, start `verifyImages` in `Audit` to find
  unsigned workloads, migrate teams to signing in CI, then `Enforce`.
- **Handle third-party and base images.** You won't control signatures for every
  upstream image; use scoped `imageReferences` and governed exceptions for vetted
  external images rather than disabling the policy.

---

## 7. Common mistakes

- **Requiring "a signature" but not an identity.** `required: true` with no
  `subject`/`issuer` lets an attacker sign their own malicious image and pass. *Fix:*
  always pin certificate identity, issuer, and registry path.
- **Signing the tag, reasoning about the tag.** Signatures bind to digests; if you
  verify a tag but deploy without digest pinning, the tag can be swapped after
  verification. *Fix:* `mutateDigest: true` so the verified digest is what runs.
- **Long-lived signing keys in CI.** A private key in a CI secret is a leak waiting to
  happen and undermines the whole scheme. *Fix:* keyless (OIDC) signing, or a KMS-held
  key you never export.
- **Verifying in a script, not at admission.** A verify step a team can forget or skip
  is not a control. *Fix:* enforce with a `verifyImages` ClusterPolicy so there's no
  bypass.
- **Treating a signature as a safety certificate.** Signed ≠ safe; a signed image can
  still be vulnerable. *Fix:* keep scanning and attestation (13.5) alongside signing.
- **Enforcing cluster-wide on day one.** Flipping `verifyImages` to `Enforce` before
  pipelines sign breaks every deploy. *Fix:* audit, migrate, then enforce.

---

## 8. Assessment

**Knowledge checks**

1. What two properties does verifying an image signature establish, and what does it
   *not* establish?
2. In keyless signing, what do Fulcio and Rekor each provide?
3. Why must a verification policy pin the signer **identity**, not just require "a
   signature"?
4. What does `mutateDigest: true` prevent?

**Concept exercise**

> Explain how a cluster can guarantee it only runs images your build pipeline produced
> **without using the words "Cosign," "signature," or "Kyverno."** Describe the
> guarantee and the trust anchor, not the tools.

**Trade-off / debugging exercise**

> A `verifyImages` policy is set to `required: true` for `ghcr.io/org/*` but has no
> identity constraints. A red-team pushes `ghcr.io/org/evil:1.0`, signs it keyless with
> their *own* GitHub identity, and it runs. Explain exactly why the policy let it
> through, what you'd add to stop it, and how the same policy should treat a legitimate
> third-party base image you don't build.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Proves / not:** integrity (bytes match the signed digest) and provenance/
  authenticity (a named identity signed it). It does **not** prove the image is safe or
  vulnerability-free.
- **Fulcio / Rekor:** Fulcio is the CA that issues a short-lived certificate bound to
  an OIDC identity (no long-lived key); Rekor is the immutable, public transparency log
  that records the signature for later audit.
- **Pin identity:** a bare "require a signature" is satisfied by *any* valid signature,
  including one the attacker made for their own image. Pinning `subject`/`issuer`
  (and registry path) means only your pipeline's signature counts.
- **mutateDigest:** it rewrites the image reference to the verified `sha256:` digest, so
  the exact bytes that were verified are the bytes that run — closing the tag-swap race
  between check and pull.
- **Debugging:** the policy required *a* signature but constrained no identity, so the
  attacker's own keyless signature passed. Add `attestors.entries.keyless.subject` /
  `issuer` pinned to your pipeline and the `ghcr.io/org/*` path. For a legitimate
  external base image you don't build, scope `imageReferences` precisely and allow it
  via a separate rule or a governed, time-boxed `PolicyException` (and still scan it) —
  don't weaken the whole policy.

</details>

---

## 9. Further reading

- Sigstore — [Cosign documentation](https://docs.sigstore.dev/cosign/overview/)
- Sigstore — [Keyless signing (Fulcio & Rekor)](https://docs.sigstore.dev/cosign/signing/overview/)
- Kyverno — [Verify Images reference](https://kyverno.io/docs/writing-policies/verify-images/)
- Sigstore — [Rekor transparency log](https://docs.sigstore.dev/logging/overview/)
- SLSA — [Provenance and verification](https://slsa.dev/spec/v1.0/provenance)
- GitHub — [OIDC for signing in Actions](https://docs.github.com/en/actions/security-guides/using-openid-connect-with-reusable-workflows)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.5 — Supply Chain Security](../05-supply-chain-security/)
· _Next:_ [Module 13.7 — Runtime Security →](../07-runtime-security/)
