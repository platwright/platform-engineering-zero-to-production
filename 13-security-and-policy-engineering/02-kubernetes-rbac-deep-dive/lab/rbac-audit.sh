#!/usr/bin/env bash
set -euo pipefail

# rbac-audit.sh — the smallest honest sweep for over-broad RBAC grants (OWASP K03).
# Requires: a configured kubectl context and jq.
# Each section prints a header, then its findings. Nothing here changes the cluster.

echo "== (a) ClusterRoleBindings whose subjects include a ServiceAccount =="
# Machine identities bound CLUSTER-WIDE: a leaked token here reaches every namespace.
kubectl get clusterrolebindings -o json \
  | jq -r '.items[]
      | select(.subjects != null)
      | select(any(.subjects[]; .kind == "ServiceAccount"))
      | .metadata.name as $name
      | .roleRef.name as $role
      | .subjects[]
      | select(.kind == "ServiceAccount")
      | "\($name)\tSA=\(.namespace // "-")/\(.name)\t-> \($role)"'

echo
echo "== (b) Who holds cluster-admin? (should be a tiny, known list) =="
kubectl get clusterrolebindings -o json \
  | jq -r '.items[]
      | select(.roleRef.name == "cluster-admin")
      | .subjects[]?
      | "\(.kind)/\(.namespace // "-")/\(.name)"' \
  | sort -u

echo
echo "== (c) ClusterRoles granting wildcard (*) verbs, resources, or apiGroups =="
kubectl get clusterroles -o json \
  | jq -r '.items[]
      | select(any(.rules[]?;
                (((.verbs     // []) | index("*")) != null)
             or (((.resources // []) | index("*")) != null)
             or (((.apiGroups // []) | index("*")) != null)))
      | "ClusterRole/\(.metadata.name)"' \
  | sort -u

echo
echo "== (c) Namespaced Roles granting wildcard (*) verbs, resources, or apiGroups =="
kubectl get roles --all-namespaces -o json \
  | jq -r '.items[]
      | select(any(.rules[]?;
                (((.verbs     // []) | index("*")) != null)
             or (((.resources // []) | index("*")) != null)
             or (((.apiGroups // []) | index("*")) != null)))
      | "Role/\(.metadata.namespace)/\(.metadata.name)"' \
  | sort -u

echo
echo "== (d) RoleBinding count per namespace =="
kubectl get rolebindings --all-namespaces -o json \
  | jq -r '.items[].metadata.namespace' \
  | sort | uniq -c | sort -rn
