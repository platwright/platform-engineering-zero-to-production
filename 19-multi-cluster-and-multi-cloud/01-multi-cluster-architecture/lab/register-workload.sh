#!/usr/bin/env bash
# Register the workload cluster with Argo CD on the management cluster, ATTACH segment
# labels (environment, region), then rewrite the stored API endpoint to the cluster's
# address on the shared 'kind' docker network so the hub's Argo CD pods can reach it.
#
# WHY THE REWRITE: kind writes each cluster's kubeconfig with server https://127.0.0.1:<port>,
# reachable only from your laptop — not from a pod inside the management cluster. Both kind
# clusters share the 'kind' docker network, so the workload API server is reachable from the
# hub at https://<container-ip>:6443. On real cloud clusters the endpoints are routable and
# this whole step disappears — you would just `argocd cluster add` with labels.
#
# WHY THE LABELS: the cluster generator's selector matches on these labels, and the template
# reads {{metadata.labels.*}} from them. They are what makes a cluster part of a segment.
#
# Needs: argocd CLI (logged in), kubectl, docker, and GNU base64 (Linux/WSL2).
# Run from this lab directory:  bash register-workload.sh
set -euo pipefail

MGMT_CTX=kind-pe-mgmt
WORKLOAD_CTX=kind-pe-prod-eu
WORKLOAD_CONTAINER=pe-prod-eu-control-plane

echo ">> adding the workload cluster to Argo CD with segment labels"
argocd cluster add "$WORKLOAD_CTX" --name pe-prod-eu \
  --label environment=prod --label region=eu --yes

echo ">> finding the workload API server IP on the 'kind' docker network"
WORKLOAD_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$WORKLOAD_CONTAINER")
INTERNAL="https://${WORKLOAD_IP}:6443"

echo ">> rewriting the stored cluster endpoint to $INTERNAL"
SECRET=$(kubectl --context "$MGMT_CTX" -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster -o name | head -1)
kubectl --context "$MGMT_CTX" -n argocd patch "$SECRET" --type merge \
  -p "{\"data\":{\"server\":\"$(printf '%s' "$INTERNAL" | base64 | tr -d '\n')\"}}"

echo ">> done. Registered clusters and their segment labels:"
kubectl --context "$MGMT_CTX" -n argocd get secret \
  -l argocd.argoproj.io/secret-type=cluster \
  -o custom-columns=NAME:.metadata.name,ENV:.metadata.labels.environment,REGION:.metadata.labels.region
