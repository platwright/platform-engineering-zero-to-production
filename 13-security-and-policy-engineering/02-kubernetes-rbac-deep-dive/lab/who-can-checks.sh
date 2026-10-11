#!/usr/bin/env bash
set -uo pipefail

# who-can-checks.sh — "who can do X?" for sensitive, high-blast-radius actions.
#
# OPTIONAL tool (cleanest answers): the kubectl-who-can krew plugin —
#   kubectl krew install who-can      # https://github.com/aquasecurity/kubectl-who-can
#
# Each check prints the SUBJECTS allowed to perform a sensitive action. If the plugin
# is missing, use the FALLBACK under each line: it checks the inverse ("can THIS
# subject do X?") by impersonating a subject you name.

if ! kubectl who-can --help >/dev/null 2>&1; then
  echo "kubectl-who-can is not installed — use the auth can-i fallbacks below."
  echo "Enumerate ANY subject's full effective permissions with:"
  echo "  kubectl auth can-i --list --as=system:serviceaccount:<ns>:<sa> [-n <ns>]"
  exit 0
fi

echo "== Who can delete pods in all namespaces? =="
kubectl who-can delete pods --all-namespaces
# Fallback: kubectl auth can-i delete pods -A --as=system:serviceaccount:<ns>:<sa>

echo
echo "== Who can create clusterrolebindings? (privilege escalation) =="
kubectl who-can create clusterrolebindings
# Fallback: kubectl auth can-i create clusterrolebindings --as=system:serviceaccount:<ns>:<sa>

echo
echo "== Who can read Secrets in all namespaces? =="
kubectl who-can get secrets --all-namespaces
# Fallback: kubectl auth can-i get secrets -A --as=system:serviceaccount:<ns>:<sa>

echo
echo "== Who can do anything ('*' '*')? (cluster-admin-equivalent) =="
kubectl who-can '*' '*'
# Fallback: kubectl auth can-i '*' '*' --as=system:serviceaccount:<ns>:<sa>

echo
echo "== Who can impersonate users? (lets a subject become anyone) =="
kubectl who-can impersonate users
# Fallback: kubectl auth can-i impersonate users --as=system:serviceaccount:<ns>:<sa>
