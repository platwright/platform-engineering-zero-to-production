#!/usr/bin/env bash
#
# bootstrap.sh — Pass 1: stand up the LGTM + OTel observability stack on a local
# kind cluster using Helm. Idempotent and safe to re-run.
#
# WARNING: this stack is memory-hungry. Give Docker >= 8 GB.
#
# Usage:  ./scripts/bootstrap.sh
# Env:    CLUSTER_NAME (default: observability-platform)

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-observability-platform}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NS=observability
CFG="${PROJECT_ROOT}/config-repo/platform"

echo "==> Creating kind cluster '${CLUSTER_NAME}' (if absent)"
if kind get clusters 2>/dev/null | grep -qx "${CLUSTER_NAME}"; then
  echo "    cluster already exists; reusing it"
else
  kind create cluster --name "${CLUSTER_NAME}"
fi

echo "==> Adding Helm repositories"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null
helm repo add grafana https://grafana.github.io/helm-charts >/dev/null
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts >/dev/null
helm repo update >/dev/null

kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

echo "==> Installing kube-prometheus-stack (Prometheus + Grafana + Alertmanager)"
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  -n "${NS}" -f "${CFG}/prometheus/prometheus-values.yaml" --wait --timeout 10m

echo "==> Installing Loki (logs) and Tempo (traces)"
helm upgrade --install loki grafana/loki -n "${NS}" -f "${CFG}/loki/loki-values.yaml" --wait --timeout 10m
helm upgrade --install tempo grafana/tempo -n "${NS}" -f "${CFG}/tempo/tempo-values.yaml" --wait --timeout 10m

echo "==> Installing OTel Collector (gateway Deployment + agent DaemonSet)"
helm upgrade --install otel-gateway open-telemetry/opentelemetry-collector \
  -n "${NS}" -f "${CFG}/otel-collector/otel-values.yaml" --set mode=deployment --wait --timeout 5m
helm upgrade --install otel-agent open-telemetry/opentelemetry-collector \
  -n "${NS}" -f "${CFG}/otel-collector/otel-values.yaml" --set mode=daemonset --wait --timeout 5m

echo "==> Applying a sample alert rule"
kubectl apply -f "${CFG}/prometheus/sample-alert-rule.yaml"

cat <<EOF

Observability platform is up in namespace '${NS}'. Explore it:

  # Grafana (user: admin, password: admin — LOCAL ONLY):
  kubectl -n ${NS} port-forward svc/kube-prometheus-stack-grafana 3000:80
  # open http://localhost:3000 → Explore → Prometheus / Loki / Tempo

  kubectl -n ${NS} get pods

Next: follow build-guide.md to instrument the sample app, import the Platform
Overview Dashboard (dashboards/platform-overview.json), and make an SLO alert fire.
Tear everything down with: ./scripts/cleanup.sh
EOF
