#!/usr/bin/env bash
#
# bootstrap.sh — Pass 1: stand up the GitOps platform on a local kind cluster.
# Creates a cluster, installs ArgoCD, and applies the app-of-apps root Application
# pointed at YOUR config repo. Idempotent and safe to re-run.
#
# Prereq: you have pushed this project's config-repo/ contents to your own Git host
# and replaced the __CONFIG_REPO_URL__ placeholder there (see build-guide.md).
#
# Usage:
#   export CONFIG_REPO_URL="https://github.com/<you>/gitops-config.git"
#   ./scripts/bootstrap.sh
# Env:
#   CLUSTER_NAME (default: gitops-platform)

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-gitops-platform}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ -z "${CONFIG_REPO_URL:-}" ]; then
  echo "ERROR: set CONFIG_REPO_URL to your config repo, e.g.:" >&2
  echo "  export CONFIG_REPO_URL=https://github.com/<you>/gitops-config.git" >&2
  exit 1
fi

echo "==> Creating kind cluster '${CLUSTER_NAME}' (if absent)"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "    cluster already exists; reusing it"
else
  kind create cluster --name "${CLUSTER_NAME}"
fi

echo "==> Installing ArgoCD"
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "==> Waiting for ArgoCD to become ready (this can take a couple of minutes)"
kubectl -n argocd rollout status deploy/argocd-server --timeout=300s
kubectl -n argocd rollout status deploy/argocd-applicationset-controller --timeout=300s

echo "==> Applying the app-of-apps root (pointed at ${CONFIG_REPO_URL})"
sed "s|__CONFIG_REPO_URL__|${CONFIG_REPO_URL}|g" "${PROJECT_ROOT}/bootstrap/root-app.yaml" \
  | kubectl apply -f -

cat <<EOF

GitOps platform bootstrapping. Watch ArgoCD converge:

  # Admin password:
  kubectl -n argocd get secret argocd-initial-admin-secret \\
    -o jsonpath='{.data.password}' | base64 -d; echo

  # Port-forward the UI (then open https://localhost:8080, user: admin):
  kubectl -n argocd port-forward svc/argocd-server 8080:443

  # Or watch from the CLI:
  kubectl -n argocd get applications

You should see: 'root', 'platform', and one Application per team/service/env.
dev + staging auto-sync; prod stays OutOfSync until you sync it manually.

See build-guide.md for the promotion, self-heal, and rollback exercises.
Tear everything down with: ./scripts/cleanup.sh
EOF
