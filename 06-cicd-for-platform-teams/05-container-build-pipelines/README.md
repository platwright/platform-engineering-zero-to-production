# Module 06.5 — Container Build Pipelines

> This is the pipeline the whole course has been pointing at: the one that turns
> source code into a **signed, scanned, immutable** container image that production
> will trust. You'll assemble the full arc — `lint → test → build → scan → sign →
> push` — with layer caching, multi-arch builds, a vulnerability **gate**, an SBOM,
> **keyless** signing with Cosign, and promotion by **digest**. This is the engine of
> Project 1.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 06.2](../02-github-actions-deep-dive/),
[Phase 2 · Containerization](../../02-containerization/), Docker, and
[Trivy](https://trivy.dev/). Cosign is installed in the lab. The core lab is local/free.

## Learning objectives

By the end of this module you will be able to:

- Assemble a container pipeline: `lint → test → build → scan → sign → push`.
- Speed builds with **registry / GitHub Actions layer caching** and build **multi-arch**.
- Gate on vulnerabilities with **Trivy** (fail on critical CVEs).
- Generate an **SBOM** as a pipeline artifact and attestation.
- **Sign images keylessly** with Cosign via OIDC — no stored keys.
- **Promote by digest** so the exact bytes you scanned are what reaches production.

---

## 1. Concept

### The pipeline arc, and why the order is the lesson

```text
lint → test → build → scan → sign → push
 │      │       │       │      │      └ publish the exact artifact you just vouched for
 │      │       │       │      └ cryptographically attest "this pipeline built this digest"
 │      │       │       └ GATE: block if the image has critical, fixable CVEs
 │      │       └ produce an immutable image + its digest
 │      └ fail fast on logic errors before the expensive build
 └ cheapest checks first (Dockerfile lint, formatting)
```

The order encodes the failure philosophy from Module 06.1: cheap, decisive checks
first; the **scan is a gate** that runs *before* you sign or push, so a vulnerable
image can't be blessed; and you **sign then push** the *same* artifact you scanned.
Signing a different image than you scanned would defeat the whole point.

### Caching: don't rebuild the world every time

A cold container build re-downloads base layers and re-runs every step. **Layer
caching** reuses unchanged layers across runs. Two common backends in CI:

- **GitHub Actions cache** (`cache-from/to: type=gha`) — convenient, scoped to the repo.
- **Registry cache** (`type=registry,ref=…`) — shared across runners and repos, better
  for an org-wide base image.

Combined with Buildx, caching turns multi-minute builds into seconds when only your
app layer changed — which matters a lot when every team's pipeline runs this.

### Multi-arch: build for every CPU your fleet runs

Clusters increasingly mix `amd64` and `arm64` (Graviton, Ampere, Apple silicon dev
machines). You build **both** from one pipeline using Buildx + QEMU emulation, and push
a **multi-arch manifest** — a single tag that resolves to the right architecture per
node. One image reference, correct everywhere.

### The vulnerability gate

Module 02.5 taught scanning; here it becomes a **gate**. Trivy compares the image's
packages against CVE databases; `--exit-code 1 --severity CRITICAL` makes a critical,
fixable finding **fail the build** so the image is never signed or pushed. Use
`--ignore-unfixed` so you block on things you can actually fix, not noise you can't.

### SBOM: a bill of materials you can query later

A **Software Bill of Materials** lists every package and version in the image. Generate
it in the pipeline (Trivy or Syft, CycloneDX/SPDX format), keep it as an **artifact**,
and **attest** it to the image. When the next Log4Shell drops, "are we affected?"
becomes a query against stored SBOMs instead of a frantic week of archaeology.

### Keyless signing with Cosign

How does production know an image came from *your* pipeline and not an attacker's
laptop? You **sign** it. The old way needs a private key you must store and rotate — the
same long-lived-secret problem as cloud auth. **Keyless Cosign** removes the key
entirely, using the OIDC identity from Module 06.2:

```text
1. The runner requests an OIDC token (id-token: write): "I am repo X, workflow Y."
2. Cosign gets a SHORT-LIVED certificate from Fulcio bound to that identity.
3. Cosign signs the image's DIGEST with that ephemeral key and logs it to Rekor
   (a public transparency log) — then the key is thrown away.
4. Verifiers check the signature + certificate identity + issuer. No key was stored.
```

You verify with the *expected identity*: "only images signed by
`repo = platform-org/service-* , issuer = GitHub Actions` may run in production"
(enforced by policy in Phase 13). No key to leak, and the signature is tied to exactly
*which workflow in which repo* produced the image.

### Promotion by digest, not tag

A tag like `:latest` or `:v1.2` is **mutable** — it can be re-pointed at new bytes. A
**digest** (`@sha256:…`) names the *exact content* and cannot change. So you **promote
the same image across environments by digest**: build and scan once in dev, and move
*that digest* to staging and production. You never rebuild per environment (a rebuild is
a different image you didn't scan). Immutable promotion is how "what we tested is what we
ship" becomes literally true.

```text
build once ─► ghcr.io/org/app@sha256:abc…   (scanned, signed)
                    │ promote the SAME digest, unchanged
        dev ───────┼──────── staging ──────── production
   (tag :dev)      (tag :staging)        (tag :prod)   ← tags are just pointers;
                                                          the digest is the truth
```

---

## 2. Why it matters for platform engineering

This pipeline is where the platform *keeps its security promises mechanically*. "Every
production image is scanned, has an SBOM, and is signed by our pipeline" is only true if
a pipeline every image must pass makes it true. Bake the gate, SBOM, and signature into
the golden-path template (Module 06.4) and every team gets them by default — structural
security, not a checklist someone might skip.

Keyless signing plus digest promotion close the supply-chain loop. Signing binds an
image to the exact workflow that built it; digest promotion guarantees the bytes you
scanned are the bytes that run; and verification at the deployment gate means a
hand-built or tampered image simply can't reach production. That chain — build → scan →
sign → verify → admit — is the backbone of Project 1 and a cornerstone of SLSA-style
supply-chain integrity.

## 3. Mental model

```text
      CONTAINER BUILD PIPELINE — trust, assembled step by step
      ───────────────────────────────────────────────────────

  source ─► [lint] ─► [test] ─► [BUILD]──────────► image + DIGEST (immutable id)
                                 Buildx            │
                                 multi-arch        ├─► [SCAN]  Trivy ──► CRITICAL? ──► ✗ fail (gate)
                                 cache: gha/reg    │                      else ▼
                                                   ├─► [SBOM]  CycloneDX ─► artifact + attestation
                                                   ▼
                                           [SIGN] Cosign keyless (OIDC → Fulcio → Rekor)
                                                   ▼
                                           [PUSH] the SAME digest you scanned & signed
                                                   ▼
          promote by DIGEST:  dev ──► staging ──► production   (verify signature at the gate)

  One line: build once, scan as a gate, sign keylessly, and promote the immutable
            digest everywhere — so what you tested is provably what you run.
```

## 4. Minimal implementation

Before the full workflow, feel each trust step by hand, locally and free. First, the
**gate** — a scan that *fails* on a critical finding (exactly what CI will do):

```bash
# Build your image, then gate on it. A non-zero exit = the build should stop.
docker build -t app:dev .
trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed app:dev
echo "exit code was: $?"   # 0 = clean (proceed), 1 = blocked (never sign/push)
```

Then an **SBOM** you could query later:

```bash
trivy image --format cyclonedx --output sbom.cdx.json app:dev
```

Then the idea of a **signature** (here with a local key to see the shape; CI is keyless):

```bash
cosign generate-key-pair                      # local demo only
cosign sign-blob --key cosign.key sbom.cdx.json > sbom.sig
cosign verify-blob --key cosign.pub --signature sbom.sig sbom.cdx.json  # -> Verified OK
```

In CI there is **no `cosign.key`** — the identity comes from OIDC and the key is
ephemeral. The lab builds the full keyless, digest-promoting workflow; here you've seen
that each step is just "produce the artifact, prove something about it, carry the proof."

## 5. Hands-on lab

You'll build a tiny image, run the **vulnerability gate** and watch it block a critical
CVE, generate and inspect an **SBOM**, see a **signature** verify, and reason about
**digest** promotion. Then you'll validate the full `container-ci.yml`
(`build → scan → sign → push`, multi-arch, keyless Cosign) with `actionlint`. Local and
free; running it on GitHub is an optional, marked extension.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Scan continuously, not just at build.** New CVEs land daily; re-scan images already
  in registries and alert, don't only gate at build time.
- **Gate on fixable criticals; triage the rest.** Block on `CRITICAL` + fixable to stay
  actionable; track unfixable/high findings without halting every build.
- **Pin and rebuild base images.** Track base-image digests; rebuild on disclosures.
  Minimal/distroless bases (Module 02.5) make this cheap.
- **Verify signatures at admission.** Signing is only half the value — enforce
  "verify by expected identity" at the deployment gate (Kyverno/Cosign policy, Phase 13).
- **Promote by digest, always.** Never let an environment rebuild; move the signed digest.
  Tags are human conveniences layered on top.
- **Cache safely.** Caches speed builds but can poison them if shared across trust
  boundaries; scope caches per repo/base and don't cache secrets.
- **Keep SBOMs and provenance.** Store them as attestations so audits and CVE hunts are
  queries, not excavations.

## 7. Common mistakes

- **Scanning *after* pushing (or not gating)** — the vulnerable image is already
  published. *Fix:* scan before sign/push and make it a gate (`--exit-code 1`).
- **Signing a tag, then pushing a different build** — the signature doesn't cover what
  ran. *Fix:* sign and promote by **digest**, the immutable identity.
- **Storing a Cosign private key as a secret** — the long-lived-key problem again.
  *Fix:* keyless signing via OIDC (`id-token: write`), no stored key.
- **Rebuilding per environment** — "staging" and "prod" are now different, unscanned
  images. *Fix:* build once; promote the same digest.
- **Gating on every severity including unfixable** — builds fail on noise nobody can fix,
  so teams disable the gate. *Fix:* `--ignore-unfixed`, block on critical/fixable.
- **No multi-arch, then `exec format error` on arm64 nodes** — amd64-only image on an
  arm64 node. *Fix:* build `linux/amd64,linux/arm64` and push a manifest.
- **No SBOM** — a new CVE turns into a week of "which images even contain this?" *Fix:*
  generate and attest an SBOM every build.

## 8. Assessment

**Knowledge checks**

1. Why must the scan run *before* sign and push, and why is `--exit-code 1` essential?
2. What does keyless Cosign replace, and where does the signing identity come from?
3. Why promote by digest instead of by tag across environments?
4. What is an SBOM and what future problem does storing one solve?
5. How do you build an image that runs on both `amd64` and `arm64` nodes from one
   pipeline?

**Concept exercise**

> Explain how production can be sure an image came from the official pipeline and hasn't
> been tampered with — **without using the words "sign," "key," or "Cosign."** Describe
> what is produced, what is checked, and what makes it trustworthy.

**Trade-off / debugging exercise**

> A team's pipeline builds `app:latest`, pushes it, *then* scans `app:latest`, and signs
> `app:latest` in a separate later job. Production pulls `app:latest`. Identify three ways
> this can ship an unsafe or wrong image to production, and the specific change that fixes
> each.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** So a vulnerable image is never blessed or published; the scan must be able to
  **fail the build** (`--exit-code 1`), otherwise it's advisory and the pipeline proceeds
  anyway (a silent skip).
- **Q2:** It replaces a stored private signing key. The identity comes from the workflow's
  OIDC token (repo + workflow), which Fulcio binds to a short-lived certificate; the
  signature is recorded in Rekor.
- **Q3:** A digest names exact bytes and is immutable; a tag can be re-pointed. Promoting
  by digest guarantees staging/prod run exactly what you scanned and signed.
- **Q4:** A list of every package/version in the image; stored SBOMs turn "are we exposed
  to CVE-X?" into a fast query instead of re-scanning or guessing.
- **Q5:** Use Buildx with QEMU to build `linux/amd64,linux/arm64` and push a multi-arch
  manifest that resolves per node.
- **Debugging:** (1) Push-before-scan publishes a bad image → scan before push as a gate.
  (2) `:latest` is mutable, so the scanned/signed image may differ from what prod pulls →
  promote by digest. (3) Signing in a separate later job on a tag doesn't bind to the
  scanned build → sign the digest in the same job, immediately after the gate.

</details>

## 9. Further reading

- Docker — [Multi-platform builds](https://docs.docker.com/build/building/multi-platform/) and [GitHub Actions cache](https://docs.docker.com/build/cache/backends/gha/)
- Sigstore — [Cosign: keyless signing](https://docs.sigstore.dev/cosign/signing/overview/) and [verifying](https://docs.sigstore.dev/cosign/verifying/verify/)
- Aqua Security — [Trivy GitHub Action](https://github.com/aquasecurity/trivy-action)
- CycloneDX — [SBOM standard](https://cyclonedx.org/) · Anchore — [Syft](https://github.com/anchore/syft)
- SLSA — [Supply-chain Levels for Software Artifacts](https://slsa.dev/)
- GitHub — [Building and pushing Docker images (OIDC to registries)](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 06.4 — Pipeline Templates as a Platform Product](../04-pipeline-templates-as-product/) · _Next:_ [Module 06.6 — IaC Pipelines](../06-iac-pipelines/)
