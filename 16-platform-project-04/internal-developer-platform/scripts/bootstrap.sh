#!/usr/bin/env bash
#
# bootstrap.sh — Pass 1: scaffold and run Backstage locally with the course catalog
# and the two golden-path templates, so you can demo the IDP without any cloud.
#
# This does NOT vendor a full Backstage app into the repo (that's thousands of
# node_modules files). It creates the app in a sibling working directory and layers
# in the config from backstage/.
#
# Usage:  ./scripts/bootstrap.sh [target-dir]
# Needs:  Node.js 20+, Yarn

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="${1:-$PROJECT_ROOT/../.idp-app}"

command -v node >/dev/null || { echo "ERROR: Node.js 20+ is required." >&2; exit 1; }

echo "==> Scaffolding a Backstage app at: ${APP_DIR}"
if [ -d "${APP_DIR}" ]; then
  echo "    app already exists; reusing it"
else
  npx @backstage/create-app@latest --path "${APP_DIR}"
fi

cat <<EOF

Backstage app scaffolded. Now wire in the IDP config:

  1. Merge this project's backstage/app-config.idp.yaml into:
       ${APP_DIR}/app-config.yaml
     (adjust the catalog/template 'target:' paths to point at THIS project's
      backstage/catalog/org.yaml and golden-paths/*/template.yaml)

  2. (Pass 2) export GITHUB_TOKEN, AUTH_GITHUB_CLIENT_ID, AUTH_GITHUB_CLIENT_SECRET

  3. Start it:
       cd "${APP_DIR}" && yarn install && yarn dev
     Open http://localhost:3000 -> Catalog and 'Create' should show the course
     catalog and the Go / Python golden-path templates.

See build-guide.md for the full walkthrough (scaffolding a service, GitOps hand-off).
Tear down with: ./scripts/cleanup.sh "${APP_DIR}"
EOF
