#!/usr/bin/env bash
# weekly-cost-report.sh — a per-team (per-namespace) cost summary from OpenCost.
#
# This is the "push, don't pull" half of showback: a job you run on a schedule that
# turns the OpenCost allocation API into a short report and (optionally) posts it to a
# team's Slack channel.
#
# Usage:
#   ./weekly-cost-report.sh sample-allocation.json     # read a saved response (offline)
#   OPENCOST_URL=http://localhost:9003 ./weekly-cost-report.sh   # query live OpenCost
#   WINDOW=24h ./weekly-cost-report.sh                 # override the window (default 7d)
#
# If SLACK_WEBHOOK_URL is set, the report is also posted to Slack.
set -euo pipefail

WINDOW="${WINDOW:-7d}"
SRC="${1:-}"

if [[ -n "$SRC" ]]; then
  [[ -f "$SRC" ]] || { echo "file not found: $SRC" >&2; exit 1; }
  json="$(cat "$SRC")"
  source_label="sample file $SRC"
else
  OPENCOST_URL="${OPENCOST_URL:-http://localhost:9003}"
  json="$(curl -sfG "$OPENCOST_URL/allocation/compute" \
            --data-urlencode "window=$WINDOW" \
            -d aggregate=namespace -d accumulate=true)"
  source_label="$OPENCOST_URL (window=$WINDOW)"
fi

# Per-namespace lines, most expensive first, rounded to cents.
lines="$(printf '%s' "$json" | jq -r '
  .data[0] | to_entries
  | sort_by(-.value.totalCost)
  | .[] | "• \(.key): $\(((.value.totalCost)*100|round)/100)"')"

total="$(printf '%s' "$json" | jq -r '
  [.data[0][].totalCost] | add | (.*100|round)/100')"

header="Weekly cost report — source: ${source_label}"
body="${lines}"$'\n'"— total: \$${total}"

printf '%s\n%s\n' "$header" "$body"

if [[ -n "${SLACK_WEBHOOK_URL:-}" ]]; then
  payload="$(jq -n --arg t "$header" --arg b "$body" '{text: ($t + "\n" + $b)}')"
  curl -sS -X POST -H 'Content-type: application/json' \
    --data "$payload" "$SLACK_WEBHOOK_URL" >/dev/null && echo "(posted to Slack)"
fi
