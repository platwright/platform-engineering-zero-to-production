#!/usr/bin/env bash
# A hand-built GitOps agent, in the clear.
#
# It does exactly what Argo CD and Flux do, minus the UI, health checks,
# pruning, ordering, and RBAC: observe desired state in Git, then reconcile
# the cluster toward it — forever.
#
# Usage:  ./reconcile.sh [path-to-config-clone]
# Env:    INTERVAL=seconds (default 15)

set -euo pipefail

REPO_DIR="${1:-.}"                  # a Git checkout of the config repo
MANIFESTS="${REPO_DIR}/manifests"   # the declarative desired state
INTERVAL="${INTERVAL:-15}"          # seconds between reconciles

echo "GitOps loop: reconciling '${MANIFESTS}' every ${INTERVAL}s. Ctrl-C to stop."
while true; do
  # 1. OBSERVE desired state: pull from the remote (a real agent fetches merged PRs).
  git -C "${REPO_DIR}" pull --quiet || true
  # 2 + 3. COMPARE and CONVERGE: make the cluster match the manifests.
  kubectl apply -f "${MANIFESTS}" >/dev/null
  echo "$(date '+%H:%M:%S')  reconciled to $(git -C "${REPO_DIR}" rev-parse --short HEAD)"
  # 4. ...and never stop. Drift introduced out-of-band is undone on the next tick.
  sleep "${INTERVAL}"
done
