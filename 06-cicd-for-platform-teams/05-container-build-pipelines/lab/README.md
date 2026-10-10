# Lab — A build → scan → sign → push container pipeline

> You'll assemble the trust chain by hand — build an image, run the **vulnerability
> gate** and watch it block a critical CVE, generate and inspect an **SBOM**, verify a
> **signature**, and reason about **digest** promotion — then validate the full
> `container-ci.yml` (multi-arch, keyless Cosign, digest promotion) with `actionlint`.
> Everything local is free; running the workflow on GitHub is an optional, marked step.

**Estimated time:** ~60–80 minutes
**Type:** build / security
**Deliverable:** A locally built, scanned, SBOM'd image; a verified signature; and the
validated [`container-ci.yml`](./container-ci.yml) pipeline.

## Objectives

- Build an image and read its immutable **digest**.
- Run a Trivy **gate** and observe pass (exit 0) vs block (exit 1).
- Generate and inspect a **CycloneDX SBOM**.
- Verify a **signature** and understand why CI signing is keyless.
- Validate a full container pipeline with `actionlint`.

## Prerequisites

- The lesson [`../README.md`](../README.md) and
  [Phase 2 · Containerization](../../../02-containerization/).
- Docker and [Trivy](https://trivy.dev/) installed; see
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- [`actionlint`](https://github.com/rhysd/actionlint) installed.
- **Optional:** [Cosign](https://docs.sigstore.dev/system_config/installation/) for Step 5
  (installed locally; free). No cloud account is needed for Steps 1–6.
- Starter files here: [`Dockerfile`](./Dockerfile), [`main.go`](./main.go),
  [`go.mod`](./go.mod), [`container-ci.yml`](./container-ci.yml).

## Steps

1. **Validate the full pipeline.**

   ```bash
   actionlint container-ci.yml
   ```

   Expect exit 0. Open [`container-ci.yml`](./container-ci.yml) and trace the arc:
   lint → buildx (multi-arch, `cache: gha`) → **Trivy gate** (`exit-code: "1"`) → SBOM →
   **keyless** `cosign sign` of the **digest** → a gated `promote` job that *verifies*
   the signature before promoting the same digest. Note there is **no stored signing key**.

2. **Build the image and read its digest.**

   ```bash
   docker build -t app:dev .
   docker image inspect app:dev --format '{{ index .RepoDigests 0 }}{{ .Id }}'
   ```

   The `Id` (`sha256:…`) is the **digest** — the immutable name for these exact bytes.
   Tags like `app:dev` are just pointers to it.

3. **Run the vulnerability gate — pass, then block.**

   ```bash
   # Your tiny distroless image should be clean -> exit 0 (proceed).
   trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed app:dev
   echo "clean image exit: $?"

   # A deliberately old image has fixable criticals -> exit 1 (the gate fires).
   trivy image --exit-code 1 --severity CRITICAL --ignore-unfixed python:3.4-slim
   echo "old image exit: $?"
   ```

   The second command's non-zero exit is exactly what stops CI from signing or pushing a
   vulnerable image. That's the gate.

4. **Generate and inspect an SBOM.**

   ```bash
   trivy image --format cyclonedx --output sbom.cdx.json app:dev
   grep -o '"name":"[^"]*"' sbom.cdx.json | head
   ```

   You now have a queryable bill of materials. When the next big CVE drops, you grep
   SBOMs instead of guessing which images are affected.

5. **See a signature verify (local key here; CI is keyless).**

   ```bash
   COSIGN_PASSWORD="" cosign generate-key-pair           # local demo only
   cosign sign-blob --yes --key cosign.key sbom.cdx.json > sbom.sig
   cosign verify-blob --key cosign.pub --signature sbom.sig sbom.cdx.json
   ```

   You should see `Verified OK`. In `container-ci.yml` there is **no `cosign.key`** — the
   identity comes from the workflow's OIDC token and the signing key is ephemeral
   (keyless). The shape is the same: produce an artifact, attach a verifiable proof.

6. **Digest vs tag (why you promote by digest).**

   ```bash
   docker tag app:dev app:prod          # a new TAG, same bytes
   docker image inspect app:prod --format '{{ .Id }}'   # identical digest to app:dev
   ```

   Two tags, one digest. Promotion moves the **digest** between environments; the tag is
   a convenience pointer. Rebuilding for "prod" would create a *different* digest you
   never scanned — the mistake the pipeline avoids.

7. **(Optional, cloud/GitHub) Run the real keyless pipeline.**

   > **Cost & accounts note.** Running `container-ci.yml` needs a GitHub repo; it pushes
   > to **GHCR** and signs keylessly via OIDC. GitHub-hosted minutes and GHCR storage are
   > **free** within generous limits for public repos, but any registry/compute can incur
   > spend — check your plan and run the cleanup. You can skip this and still complete the
   > lab; the deliverable is the local trust chain plus the validated workflow.

   Copy `Dockerfile`, `main.go`, `go.mod`, and `container-ci.yml` (as
   `.github/workflows/container-ci.yml`) into a repo, push to `main`, and watch the gate,
   SBOM, keyless signature, and digest promotion run end to end. Verify the published
   image: `cosign verify --certificate-identity-regexp ... --certificate-oidc-issuer
   https://token.actions.githubusercontent.com ghcr.io/<you>/<repo>@<digest>`.

## Expected result

- `actionlint container-ci.yml` exits 0.
- Your image scans clean (exit 0); the old image trips the gate (exit 1).
- `sbom.cdx.json` lists packages; `cosign verify-blob` prints `Verified OK`.
- `app:dev` and `app:prod` share one digest — promotion is by digest, not tag.

## Cleanup

> No cloud resources for the local steps, but remove local images, keys, and files.

```bash
docker rmi app:dev app:prod python:3.4-slim 2>/dev/null || true
rm -f sbom.cdx.json sbom.sig cosign.key cosign.pub 2>/dev/null || true
# If you did Step 7, delete the scratch repo / its packages to avoid lingering artifacts.
```

## Reflection

- The gate blocks on `CRITICAL` + fixable. Why not block on every severity, and what
  would happen to adoption if you did?
- CI signs keylessly with no stored key. Restate, in one sentence, what an attacker gains
  by stealing a secret that *doesn't exist*.
- If production verifies "signed by `repo = platform-org/service-*`, issuer = GitHub
  Actions" at admission, why can't a developer's hand-built image ever deploy there?

## Stretch goals (optional)

- Add a `lint`/`test` job before `build` and make `build` `needs:` it, so the pipeline
  fails fast on code problems before the expensive image build.
- Switch the cache to a **registry** backend (`type=registry,ref=…`) and note when that
  beats the GitHub Actions cache.
- Attest the SBOM to the image with `cosign attest` (as the workflow does) and then
  `cosign verify-attestation` to pull it back — a full round-trip of provenance.
