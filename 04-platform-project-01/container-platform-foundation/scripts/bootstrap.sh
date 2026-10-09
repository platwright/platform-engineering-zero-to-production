#!/usr/bin/env bash
#
# bootstrap.sh — Pass 1: build the Container Platform Foundation on a local
# kind cluster (free). Idempotent and safe to re-run.
#
# Usage:  ./scripts/bootstrap.sh
# Env:    CLUSTER_NAME (default: platform-foundation)

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-platform-foundation}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Creating kind cluster '${CLUSTER_NAME}' (if it does not exist)"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "    cluster already exists; reusing it"
else
  kind create cluster --name "${CLUSTER_NAME}"
fi

echo "==> Applying the platform foundation (namespaces, limits, quotas, RBAC)"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/platform/"

echo "==> Deploying the hardened sample workload"
kubectl apply -f "${PROJECT_ROOT}/kubernetes/apps/team-a-hello.yaml"

echo "==> Waiting for the sample workload to become ready"
kubectl -n team-a rollout status deployment/hello --timeout=120s

cat <<'EOF'

Foundation is up. Explore and test the guardrails:

  kubectl get ns --show-labels
  kubectl -n team-a get deploy,pod,svc
  kubectl -n team-a describe resourcequota team-quota

  # Least-privilege checks (expect: yes, then no, then no):
  kubectl auth can-i create deployments -n team-a \
    --as=system:serviceaccount:team-a:ci-deployer
  kubectl auth can-i delete namespaces \
    --as=system:serviceaccount:team-a:ci-deployer
  kubectl auth can-i get pods -n team-b --as-group=team-a --as=alice

See build-guide.md to break the guardrails on purpose and watch them hold.
Tear everything down with: ./scripts/cleanup.sh
EOF
