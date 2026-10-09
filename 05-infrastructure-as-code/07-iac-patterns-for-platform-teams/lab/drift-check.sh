#!/usr/bin/env bash
# drift-check.sh — read-only drift detection across all environments.
#
# Runs `terraform plan -detailed-exitcode` per environment:
#   exit 0 = no drift, exit 2 = DRIFT (changes pending), exit 1 = error.
# In production you'd run this on a schedule (nightly) and turn exit 2 into an
# alert + a reconciliation PR — never an automatic apply.
set -uo pipefail

envs=(dev staging prod)
drift_found=0

for env in "${envs[@]}"; do
  echo "== $env =="
  dir="environments/$env"

  terraform -chdir="$dir" init -input=false >/dev/null

  terraform -chdir="$dir" plan -detailed-exitcode -input=false -lock=false >/dev/null 2>&1
  code=$?

  case "$code" in
    0) echo "  no drift" ;;
    2) echo "  DRIFT DETECTED — open a reconciliation PR for $env"; drift_found=1 ;;
    *) echo "  plan error (exit $code)"; drift_found=1 ;;
  esac
done

echo
if [[ "$drift_found" -eq 0 ]]; then
  echo "All environments match their code."
else
  echo "Drift or errors detected. Reconcile deliberately via pull request."
fi

exit "$drift_found"
