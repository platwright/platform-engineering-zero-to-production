#!/usr/bin/env bash
# vault-setup.sh — configure a LOCAL Vault *dev* server for the Module 13.4 lab.
#
# Dev mode is in-memory, auto-unsealed, and guarded by a known root token. It is FREE
# and local — NEVER use dev mode, or a hard-coded root token, in production.
#
# Prerequisite: Vault dev is already running in the cluster (Helm install with
# server.dev.enabled=true) as pod vault-0 in namespace "vault".
set -euo pipefail

VAULT_NS="${VAULT_NS:-vault}"
VAULT_POD="${VAULT_POD:-vault-0}"
VAULT_TOKEN="${VAULT_TOKEN:-root}"
APP_NS="${APP_NS:-my-app}"
APP_SA="${APP_SA:-my-app}"

# Run a vault CLI command inside the dev pod, with the root token exported so that
# every command in the (possibly piped) string is authenticated.
vex() {
  kubectl -n "$VAULT_NS" exec "$VAULT_POD" -- sh -c "export VAULT_TOKEN=$VAULT_TOKEN; $*"
}

echo "==> 1. Confirm a KV v2 engine is mounted at secret/"
# Dev mode already mounts a KV v2 engine at secret/. On a non-dev server you would run:
#   vault secrets enable -version=2 -path=secret kv
vex "vault secrets list | grep '^secret/'"

echo "==> 2. Write the application secret (versioned by KV v2)"
vex "vault kv put secret/my-app/db username=app password=devpassword"
vex "vault kv get secret/my-app/db"

echo "==> 3. (PRODUCTION PATTERN) Enable the Kubernetes auth method"
# The lab's SecretStore uses token auth for simplicity. In production you would NOT ship
# a token; instead Vault verifies each pod's ServiceAccount token via the Kubernetes auth
# method and binds it to a least-privilege policy. Shown here as the pattern to adopt:
vex "vault auth enable kubernetes" || echo "   (kubernetes auth may already be enabled)"

echo "==> 3a. Write a policy that allows reading ONLY this app's path"
# KV v2 read paths live under <mount>/data/<key>, hence secret/data/my-app/*.
vex "printf 'path \"secret/data/my-app/*\" { capabilities = [\"read\"] }\n' | vault policy write my-app -"

echo "==> 3b. Bind a Kubernetes ServiceAccount to that policy"
# Maps ServiceAccount $APP_NS/$APP_SA to the my-app policy with a 1h token TTL.
vex "vault write auth/kubernetes/role/my-app \
  bound_service_account_names=$APP_SA \
  bound_service_account_namespaces=$APP_NS \
  policies=my-app \
  ttl=1h" || echo "   (role write needs the kubernetes auth config; optional for the token-auth lab path)"

echo "==> Done."
echo "    Secret stored at secret/my-app/db."
echo "    The lab uses token auth (secret-store.yaml); kubernetes auth above is the"
echo "    production-grade alternative that ships NO static token to the workload."
