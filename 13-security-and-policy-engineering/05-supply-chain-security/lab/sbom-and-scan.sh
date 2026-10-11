#!/usr/bin/env bash
# sbom-and-scan.sh — build the demo image, inventory it with Syft, scan it with Grype.
#
# FREE and fully LOCAL: needs only Docker, Syft, and Grype. No registry, no cloud.
set -euo pipefail

IMAGE="${IMAGE:-pe-supply-demo:lab}"
SBOM="${SBOM:-sbom.json}"

echo "==> 1. Build the sample image from the local Dockerfile"
docker build -t "$IMAGE" .

echo "==> 2. Generate an SBOM (SPDX JSON) with Syft"
# SPDX JSON is this course's default. For the OWASP CycloneDX format instead, use:
#   syft "$IMAGE" -o cyclonedx-json=sbom.cdx.json
syft "$IMAGE" -o spdx-json="$SBOM"
echo "    Wrote $SBOM ($(wc -l < "$SBOM") lines of inventory)"

echo "==> 3. Scan the stored SBOM for known vulnerabilities"
# Scanning the SBOM (not the image) is fast and is exactly what CI does after saving the
# SBOM as a build artifact. '.grype.yaml' in this directory sets the fail-on gate.
grype "sbom:./$SBOM"

echo "==> 4. Demonstrate the CI GATE: fail the build on High/Critical"
# In CI you WANT a non-zero exit here so the pipeline stops. We append '|| ...' so this
# script keeps running and prints the exit code; drop it in a real pipeline so the job
# actually fails:
#   grype "$IMAGE" --fail-on high
grype "$IMAGE" --fail-on high || echo "    Gate would FAIL the build (exit $?) — that is the point."

echo "==> Done. SBOM written to $SBOM"
