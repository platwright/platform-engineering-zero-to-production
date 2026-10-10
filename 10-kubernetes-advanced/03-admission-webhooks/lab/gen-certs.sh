#!/usr/bin/env bash
# Generate TLS material for the mutating webhook, deploy the server, and register the
# MutatingWebhookConfiguration with the matching caBundle. Needs: openssl, kubectl.
# Run from this lab directory:  bash gen-certs.sh
set -euo pipefail

NS=platform-system
SVC=label-injector
CERT_DIR=./certs
mkdir -p "$CERT_DIR"

echo ">> ensuring namespace $NS"
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

echo ">> generating CA and server certificate (SAN: $SVC.$NS.svc)"
openssl genrsa -out "$CERT_DIR/ca.key" 2048
openssl req -x509 -new -nodes -key "$CERT_DIR/ca.key" -days 3650 \
  -subj "/CN=label-injector-ca" -out "$CERT_DIR/ca.crt"

openssl genrsa -out "$CERT_DIR/tls.key" 2048
openssl req -new -key "$CERT_DIR/tls.key" \
  -subj "/CN=$SVC.$NS.svc" -out "$CERT_DIR/tls.csr"

cat > "$CERT_DIR/san.cnf" <<EOF
subjectAltName=DNS:$SVC.$NS.svc,DNS:$SVC.$NS.svc.cluster.local
EOF

openssl x509 -req -in "$CERT_DIR/tls.csr" \
  -CA "$CERT_DIR/ca.crt" -CAkey "$CERT_DIR/ca.key" -CAcreateserial \
  -days 3650 -extfile "$CERT_DIR/san.cnf" -out "$CERT_DIR/tls.crt"

echo ">> creating TLS secret and webhook-code configmap"
kubectl -n "$NS" create secret tls webhook-tls \
  --cert="$CERT_DIR/tls.crt" --key="$CERT_DIR/tls.key" \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" create configmap webhook-code \
  --from-file=webhook.py=webhook.py \
  --dry-run=client -o yaml | kubectl apply -f -

echo ">> deploying the webhook server"
kubectl apply -f 20-webhook-server.yaml
kubectl -n "$NS" rollout status deploy/label-injector --timeout=120s

echo ">> registering the mutating webhook with the CA bundle"
CA_BUNDLE=$(base64 -w0 "$CERT_DIR/ca.crt" 2>/dev/null || base64 "$CERT_DIR/ca.crt" | tr -d '\n')
sed "s|CA_BUNDLE_PLACEHOLDER|$CA_BUNDLE|" 21-mutatingwebhook.yaml | kubectl apply -f -

echo ">> done — Pods created in managed namespaces will now get labels injected."
