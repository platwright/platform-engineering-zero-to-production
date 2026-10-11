#!/usr/bin/env bash
# attest.sh — attach the SBOM to the image as a signed attestation with Cosign.
#
# An attestation is a SIGNED statement ABOUT an artifact ("this SBOM belongs to this exact
# image, and I vouch for it"). This module GENERATES it; Module 13.6 VERIFIES it at
# admission and refuses anything unsigned.
#
# Cosign stores attestations in an OCI REGISTRY next to the image, so we use a FREE, LOCAL
# registry container (localhost:5000) — no cloud account, no cost. The OPTIONAL keyless
# path at the bottom uses a REAL registry + OIDC instead.
set -euo pipefail

IMAGE="${IMAGE:-pe-supply-demo:lab}"
SBOM="${SBOM:-sbom.json}"
REF="${REF:-localhost:5000/pe-supply-demo:lab}"
# An empty password is fine for a throwaway lab key; set COSIGN_PASSWORD to override.
export COSIGN_PASSWORD="${COSIGN_PASSWORD:-}"

if [[ ! -f "$SBOM" ]]; then
  echo "SBOM '$SBOM' not found — run ./sbom-and-scan.sh first." >&2
  exit 1
fi

echo "==> 1. (FREE/LOCAL) Start a throwaway local registry if one isn't running"
if ! docker ps --format '{{.Names}}' | grep -q '^pe-registry$'; then
  docker run -d -p 5000:5000 --name pe-registry registry:2 >/dev/null
fi

echo "==> 2. Push the image to the local registry so Cosign has a place for the attestation"
docker tag "$IMAGE" "$REF"
docker push "$REF"

echo "==> 3. (FREE/LOCAL) Generate a Cosign key pair if one doesn't exist"
# Creates cosign.key (password-protected) and cosign.pub. Share cosign.pub so others verify.
if [[ ! -f cosign.key ]]; then
  cosign generate-key-pair
fi

echo "==> 4. Attest the SBOM as an SPDX predicate, signed with the local key"
cosign attest --predicate "$SBOM" --type spdx --key cosign.key --yes "$REF"

echo "==> Done. The attestation is stored in the local registry next to $REF."
echo "    Module 13.6 uses cosign.pub to VERIFY this attestation at admission."

# --------------------------------------------------------------------------------------
# OPTIONAL — KEYLESS + REMOTE REGISTRY (needs a registry you can push to AND an OIDC
# identity; may require accounts and can incur cost). Keyless signing uses Sigstore's
# Fulcio (short-lived certs) and Rekor (transparency log) instead of a local key:
#
#   REF="ghcr.io/<your-user>/pe-supply-demo:lab"   # a real, pushable reference
#   docker tag "$IMAGE" "$REF" && docker push "$REF"
#   cosign attest --yes --type spdx --predicate "$SBOM" "$REF"
#
# There is no --key here: your identity provider signs it. Verification is Module 13.6.
# --------------------------------------------------------------------------------------
