#!/usr/bin/env bash
#
# cleanup.sh — remove the locally scaffolded Backstage app. Leaves nothing running.
#
# Usage:  ./scripts/cleanup.sh [target-dir]

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$PROJECT_ROOT/../.idp-app}"

if [ -d "${APP_DIR}" ]; then
  echo "==> Removing Backstage app at: ${APP_DIR}"
  rm -rf "${APP_DIR}"
  echo "Done. Nothing from this project is left running."
else
  echo "No app found at ${APP_DIR}; nothing to do."
fi
