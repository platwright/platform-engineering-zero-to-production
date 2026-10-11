#!/usr/bin/env bash
#
# cleanup.sh — tear down the local observability platform. Leaves nothing running.
#
# Usage:  ./scripts/cleanup.sh
# Env:    CLUSTER_NAME (default: observability-platform)

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-observability-platform}"

echo "==> Deleting kind cluster '${CLUSTER_NAME}'"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  kind delete cluster --name "${CLUSTER_NAME}"
  echo "Done. Nothing from this project is left running."
else
  echo "No cluster named '${CLUSTER_NAME}' found; nothing to do."
fi
