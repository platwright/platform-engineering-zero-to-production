#!/usr/bin/env bash
# Register the spoke cluster with Argo CD running on the hub, then rewrite the stored
# API endpoint to the spoke's address on the shared 'kind' docker network so the hub's
# Argo CD pods can actually reach it.
#
# WHY THE REWRITE: kind writes each cluster's kubeconfig with server https://127.0.0.1:<port>,
# which is only reachable from your laptop — not from a pod inside the hub cluster. Both
# kind clusters share the 'kind' docker network, so the spoke's API server is reachable
# from the hub at https://<spoke-container-ip>:6443. In a real cloud the endpoints are
# routable and this whole step disappears — you'd just `argocd cluster add`.
#
# Needs: argocd CLI (logged in), kubectl, docker, and GNU base64 (Linux/WSL2).
# Run from this lab directory:  bash register-spoke.sh
set -euo pipefail

HUB_CTX=kind-pe-hub
SPOKE_CTX=kind-pe-spoke
SPOKE_CONTAINER=pe-spoke-control-plane

echo ">> adding the spoke to Argo CD (creates a ServiceAccount on the spoke)"
argocd cluster add "$SPOKE_CTX" --name pe-spoke --yes

echo ">> finding the spoke's IP on the 'kind' docker network"
SPOKE_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$SPOKE_CONTAINER")
INTERNAL="https://${SPOKE_IP}:6443"

echo ">> rewriting the stored cluster endpoint to $INTERNAL"
SECRET=$(kubectl --context "$HUB_CTX" -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster -o name | head -1)
kubectl --context "$HUB_CTX" -n argocd patch "$SECRET" --type merge \
  -p "{\"data\":{\"server\":\"$(printf '%s' "$INTERNAL" | base64 | tr -d '\n')\"}}"

echo ">> done. Registered clusters:"
argocd cluster list
