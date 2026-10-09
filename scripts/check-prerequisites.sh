#!/usr/bin/env bash
#
# check-prerequisites.sh
# Reports which course tools are installed and their versions.
# Informational: run it any time to see what you still need to set up.
#
# Usage:  ./scripts/check-prerequisites.sh
# Exit:   0 if all CORE tools are present, 1 otherwise.
#
# See 00-orientation/environment-setup.md for installation instructions.

set -uo pipefail

GREEN=$'\033[0;32m'; YELLOW=$'\033[0;33m'; RED=$'\033[0;31m'; BOLD=$'\033[1m'; NC=$'\033[0m'

missing_core=0

# check <command> <core|optional> <purpose> <version-command>
check() {
  local cmd="$1" level="$2" purpose="$3" vcmd="$4"
  if command -v "$cmd" >/dev/null 2>&1; then
    local ver
    ver="$(eval "$vcmd" 2>&1 | head -n1 | tr -d '\r')"
    printf "  ${GREEN}[ok]${NC}      %-11s %s\n" "$cmd" "$ver"
  else
    if [ "$level" = "core" ]; then
      printf "  ${RED}[MISSING]${NC} %-11s %s\n" "$cmd" "(core) $purpose"
      missing_core=$((missing_core + 1))
    else
      printf "  ${YELLOW}[--]${NC}      %-11s %s\n" "$cmd" "(optional) $purpose"
    fi
  fi
}

printf "\n${BOLD}Platform Engineering — prerequisite check${NC}\n"
printf "%s\n\n" "-----------------------------------------"

printf "${BOLD}Core tools${NC} (needed from the early modules)\n"
check git       core "version control"                 "git --version"
check docker    core "build and run containers"        "docker --version"
check kubectl   core "operate Kubernetes clusters"     "kubectl version --client 2>/dev/null"
check kind      core "local Kubernetes clusters"       "kind version"
check terraform core "infrastructure as code"          "terraform version"
check go        core "operators and platform CLIs"     "go version"
check python3   core "automation and scripting"        "python3 --version"

printf "\n${BOLD}Recommended tools${NC} (introduced later; install as you go)\n"
check helm      optional "Kubernetes package manager"   "helm version --short 2>/dev/null"
check kustomize optional "Kubernetes config overlays"   "kustomize version 2>/dev/null"
check gcloud    optional "Google Cloud CLI"             "gcloud --version 2>/dev/null"
check jq        optional "JSON processing"              "jq --version"
check node      optional "Backstage / tooling"          "node --version"
check trivy     optional "image vulnerability scanning" "trivy --version 2>/dev/null"
check cosign    optional "image signing (Sigstore)"     "cosign version 2>/dev/null"
check argocd    optional "GitOps CLI (ArgoCD)"          "argocd version --client 2>/dev/null"

printf "\n%s\n" "-----------------------------------------"
if [ "$missing_core" -eq 0 ]; then
  printf "${GREEN}All core tools are installed. You're ready to start.${NC}\n\n"
  exit 0
else
  printf "${RED}%d core tool(s) missing.${NC} See 00-orientation/environment-setup.md to install them.\n\n" "$missing_core"
  exit 1
fi
