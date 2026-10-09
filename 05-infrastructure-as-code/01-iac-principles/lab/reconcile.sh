#!/usr/bin/env bash
# reconcile.sh — a minimal, idempotent, drift-aware "IaC engine" for teaching.
# It manages a set of files (our "resources") described by desired state below,
# persists what it manages to state.json, and acts only on the difference.
#
# Usage: ./reconcile.sh [plan|apply|destroy]
set -euo pipefail

target_dir="./managed"
state_file="./state.json"

# --- DESIRED STATE (this is our "code"): resource name -> file content ---
declare -A desired=(
  ["app.conf"]="log_level=info"
  ["db.conf"]="host=localhost port=5432"
  ["cache.conf"]="ttl=60"
)

ensure_state() {
  [[ -f "$state_file" ]] || echo '{}' > "$state_file"
}

# Read recorded content for a resource from state.json ("" if unknown).
state_get() {
  jq -r --arg k "$1" '.[$k] // ""' "$state_file"
}

# Record a resource's desired content in state.json.
state_put() {
  local tmp; tmp="$(mktemp ./state.XXXXXX)"
  jq --arg k "$1" --arg v "$2" '.[$k] = $v' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

# Remove a resource from state.json.
state_del() {
  local tmp; tmp="$(mktemp ./state.XXXXXX)"
  jq --arg k "$1" 'del(.[$k])' "$state_file" > "$tmp" && mv "$tmp" "$state_file"
}

plan() {
  ensure_state
  mkdir -p "$target_dir"
  local changes=0

  # creates + updates + drift
  for name in "${!desired[@]}"; do
    local want="${desired[$name]}"
    local path="$target_dir/$name"
    if [[ ! -f "$path" ]]; then
      if [[ -n "$(state_get "$name")" ]]; then
        echo "! drift   $name (managed file was deleted outside the tool)"
      else
        echo "+ create  $name"
      fi
      changes=1
    else
      local actual; actual="$(cat "$path")"
      local recorded; recorded="$(state_get "$name")"
      if [[ "$actual" != "$want" ]]; then
        if [[ -n "$recorded" && "$actual" != "$recorded" ]]; then
          echo "! drift   $name (changed outside the tool)"
        else
          echo "~ update  $name"
        fi
        changes=1
      fi
    fi
  done

  # destroys: in state but no longer desired
  for name in $(jq -r 'keys[]' "$state_file"); do
    if [[ -z "${desired[$name]+x}" ]]; then
      echo "- destroy $name"
      changes=1
    fi
  done

  [[ "$changes" -eq 0 ]] && echo "No changes. Infrastructure matches desired state."
  return 0
}

apply() {
  ensure_state
  mkdir -p "$target_dir"

  for name in "${!desired[@]}"; do
    local want="${desired[$name]}"
    local path="$target_dir/$name"
    if [[ ! -f "$path" || "$(cat "$path")" != "$want" ]]; then
      printf '%s\n' "$want" > "$path"
      state_put "$name" "$want"
      echo "applied   $name"
    fi
  done

  for name in $(jq -r 'keys[]' "$state_file"); do
    if [[ -z "${desired[$name]+x}" ]]; then
      rm -f "$target_dir/$name"
      state_del "$name"
      echo "destroyed $name"
    fi
  done

  echo "Converged."
}

destroy() {
  ensure_state
  for name in $(jq -r 'keys[]' "$state_file"); do
    rm -f "$target_dir/$name"
    echo "destroyed $name"
  done
  echo '{}' > "$state_file"
  echo "All managed resources destroyed."
}

case "${1:-plan}" in
  plan)    plan ;;
  apply)   apply ;;
  destroy) destroy ;;
  *) echo "usage: $0 [plan|apply|destroy]" >&2; exit 2 ;;
esac
