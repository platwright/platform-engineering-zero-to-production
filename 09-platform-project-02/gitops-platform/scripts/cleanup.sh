#!/usr/bin/env bash
#
# cleanup.sh — tear down the local GitOps platform. Leaves nothing running.
#
# Usage:  ./scripts/cleanup.sh
# Env:    CLUSTER_NAME (default: gitops-platform)

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-gitops-platform}"

echo "==> Deleting kind cluster '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Done. Nothing from this project is left running."
else
  echo "No cluster named '${CLUSTER_NAME}' found; nothing to do."
fi

echo
echo "Note: your config repo on your Git host is untouched. Delete it there if you"
echo "no longer need it."
