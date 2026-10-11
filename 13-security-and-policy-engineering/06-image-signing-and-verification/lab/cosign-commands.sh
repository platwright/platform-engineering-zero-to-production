#!/usr/bin/env bash
set -euo pipefail

# Image signing demo — runs FREE and local using the anonymous ttl.sh registry.
# In production prefer KEYLESS signing (OIDC, no stored keys); here we use a local
# key pair so the lab needs no accounts. The matching admission policy is in
# kyverno-verify-images.yaml.

# Empty passphrase for the throwaway lab key. NEVER do this for a real signing key.
export COSIGN_PASSWORD=""

# 1) Generate a local key pair: cosign.key (private) + cosign.pub (public).
cosign generate-key-pair

# 2) Build a tiny demo image from stdin (no extra files needed).
docker build -t pe-sign-demo:lab - <<'EOF'
FROM busybox:1.37
CMD ["sh", "-c", "echo signed-demo && sleep 3600"]
EOF

# 3) Push to ttl.sh — a free, anonymous, ephemeral registry (images expire in ~1h).
IMG="ttl.sh/pe-sign-$(cat /proc/sys/kernel/random/uuid):1h"
docker tag pe-sign-demo:lab "$IMG"
docker push "$IMG"

# 4) Resolve the immutable digest — signatures bind to the digest, not the tag.
DIGEST="$(docker inspect --format='{{index .RepoDigests 0}}' "$IMG")"
echo "Signing by digest: ${DIGEST}"

# 5) Sign with the private key, then verify with the public key.
cosign sign --yes --key cosign.key "${DIGEST}"
cosign verify --key cosign.pub "${DIGEST}"

# 6) Save the tag reference for the Kyverno steps (Kyverno resolves + pins the digest).
echo "${IMG}" > signed-image.txt
echo "Signed image saved to signed-image.txt: ${IMG}"
