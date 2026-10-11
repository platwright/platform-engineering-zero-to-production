# Lab — SBOM, scan, and attest a container image

> You'll build a deliberately un-hardened image, then run the three supply-chain
> moves on it: **inventory** it with Syft, **scan** that inventory with Grype (and
> turn the scan into a build gate you triage), and **attest** the SBOM with Cosign so
> a signed statement of "what's inside, and who built it" travels with the image.

**Estimated time:** ~40–55 minutes
**Type:** Build
**Deliverable:** An `sbom.json` (SPDX), a triaged Grype scan result, and a signed SBOM
attestation stored next to the image.

## Objectives

- Generate a complete SBOM for a container image and read what's inside it.
- Scan the SBOM and the image with Grype, and make a High/Critical finding **fail** a
  build.
- Triage one finding with an auditable `.grype.yaml` ignore rule.
- Attach a signed SBOM **attestation** to the image with a local Cosign key — the
  artifact Module 13.6 will verify.

## Prerequisites

- Docker, from [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md).
- A `bash` shell (Git Bash or WSL on Windows) to run the starter scripts.
- Three CLIs, each via its **official one-line installer**:
  [Syft](https://github.com/anchore/syft#installation),
  [Grype](https://github.com/anchore/grype#installation), and
  [Cosign](https://github.com/sigstore/cosign#installation). On Linux/macOS/WSL:

  ```bash
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh  | sh -s -- -b /usr/local/bin
  curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
  # Cosign (Linux amd64 release binary):
  curl -sSfLO https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
  sudo install cosign-linux-amd64 /usr/local/bin/cosign && rm cosign-linux-amd64
  ```

- Starter files in this folder: [`Dockerfile`](./Dockerfile),
  [`sbom-and-scan.sh`](./sbom-and-scan.sh), [`attest.sh`](./attest.sh), and
  [`.grype.yaml`](./.grype.yaml).

> **No Kubernetes cluster needed.** This lab is entirely image- and tool-based: it runs
> against your local Docker daemon. (Module 13.6 is where a cluster verifies these
> artifacts at admission.)

## Steps

1. **Build the sample image.** It's a deliberately non-distroless `python:3.12-slim`
   image with a couple of pip packages, so the scan has real components and CVEs:

   ```bash
   cd 13-security-and-policy-engineering/05-supply-chain-security/lab
   docker build -t pe-supply-demo:lab .
   ```

2. **Generate an SBOM with Syft.** This inventories every component in the image and
   writes it as SPDX JSON:

   ```bash
   syft pe-supply-demo:lab -o spdx-json=sbom.json
   ```

   Peek at what you now know that `docker history` never told you — the count of
   catalogued packages:

   ```bash
   grep -c '"name"' sbom.json
   ```

3. **Scan with Grype — two equivalent ways.** Scan the stored SBOM (fast, and exactly
   what CI does after saving the SBOM as an artifact), then scan the image directly:

   ```bash
   grype sbom:./sbom.json
   grype pe-supply-demo:lab
   ```

   Both report the same CVEs by severity. Note the highest-severity rows — those are
   what a gate will act on.

4. **Turn the scan into a gate, then triage one finding.** The provided
   [`.grype.yaml`](./.grype.yaml) sets `fail-on-severity: high`. Run the gate and watch
   the exit code:

   ```bash
   grype pe-supply-demo:lab --fail-on high
   echo "grype exit code: $?"
   ```

   A non-zero exit is a failed build. Now triage: pick one real CVE ID from the output,
   open `.grype.yaml`, and replace the example under `ignore:` with it and a reason:

   ```yaml
   ignore:
     # Accepted: not reachable in how we use the package; revisit YYYY-MM-DD.
     - vulnerability: CVE-2024-XXXXX
   ```

   Re-scan. Grype auto-loads `.grype.yaml`, so that one CVE is now suppressed while the
   gate still fails on everything else:

   ```bash
   grype pe-supply-demo:lab
   ```

   > Steps 1–4 are also wrapped in [`sbom-and-scan.sh`](./sbom-and-scan.sh) if you want
   > to re-run them in one shot.

5. **Attest the SBOM with Cosign (local key — free).** An attestation binds the SBOM to
   this exact image and signs it. Cosign stores attestations in a registry, so the
   script spins up a **local** registry (free, no account), pushes the image, generates
   a key pair, and attests:

   ```bash
   export COSIGN_PASSWORD=""   # empty password is fine for a throwaway lab key
   bash ./attest.sh
   ```

   Under the hood that runs the signing step:

   ```bash
   cosign attest --predicate sbom.json --type spdx --key cosign.key --yes \
     localhost:5000/pe-supply-demo:lab
   ```

   You now have `cosign.pub` — the public key Module 13.6 uses to verify this
   attestation at admission.

   > **Optional (needs accounts / may cost):** the **keyless** path pushes to a real
   > registry (for example `ghcr.io/<your-user>/pe-supply-demo:lab`) and signs with your
   > OIDC identity via Sigstore — no local key. It's shown, commented, at the bottom of
   > `attest.sh`. Skip it unless you have a registry you can push to.

## Expected result

- `sbom.json` exists and lists dozens of packages (OS libraries plus the Python
  dependencies) — a real inventory.
- `grype pe-supply-demo:lab --fail-on high` exits **non-zero** before triage, proving the
  gate works; after you add one ignore rule, that CVE disappears from the report while
  others remain.
- `attest.sh` finishes with the SBOM attestation stored next to the image in the local
  registry, and `cosign.key` / `cosign.pub` present in the folder.

You're done when you can point to three things: *what's inside* (SBOM), *what's wrong*
(a triaged scan), and *who vouches for it* (a signed attestation).

## Cleanup

> Always tear down local containers and delete keys so nothing lingers. Never commit
> `cosign.key`, and never skip this step.

```bash
docker rmi pe-supply-demo:lab localhost:5000/pe-supply-demo:lab 2>/dev/null || true
docker rm -f pe-registry 2>/dev/null || true
rm -f sbom.json sbom.cdx.json cosign.key cosign.pub cosign-linux-amd64
```

## Reflection

- Before this lab, could you have listed every package in that image? What did the SBOM
  show that `docker history` could not?
- The gate failed the build on a CVE you then *chose* to ignore. What makes that choice
  safe and auditable rather than a silent bypass?
- You generated an attestation but didn't verify it. Who should verify it, where, and
  what breaks if nobody ever does?

## Stretch goals (optional)

- Emit the SBOM in **CycloneDX** too (`syft pe-supply-demo:lab -o cyclonedx-json=sbom.cdx.json`)
  and diff what the two formats capture.
- Add the Grype gate to a CI step (a GitHub Actions job) that **fails the workflow** on
  High/Critical, uploading `sbom.json` as a build artifact.
- Drop a [Renovate](https://docs.renovatebot.com/) or
  [Dependabot](https://docs.github.com/en/code-security/dependabot) config into a repo and
  watch it open dependency-bump PRs.
- Build a second tag after bumping a dependency and **diff the SBOMs**
  (`syft ... -o spdx-json=sbom.v2.json`, then compare) to see exactly what changed.
