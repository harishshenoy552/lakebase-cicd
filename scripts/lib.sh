#!/usr/bin/env bash
# lib.sh — shared helpers for the Lakebase CI/CD pipeline.
#
# Every script sources this. Configuration comes from environment variables so
# the same scripts run identically on a laptop, a Jenkins agent, or GitHub Actions.
#
# Required env:
#   PROJECT            Lakebase project path, e.g. "projects/orders-api"
#   DATABRICKS_PROFILE Databricks CLI profile (auth)  [default: DEFAULT]
#   DB_NAME            Postgres database to operate on [default: orders]
# Optional:
#   CU_MIN / CU_MAX    Autoscaling bounds for ephemeral endpoints [0.5 / 2.0]

set -euo pipefail

: "${PROJECT:?set PROJECT, e.g. projects/orders-api}"
DATABRICKS_PROFILE="${DATABRICKS_PROFILE:-DEFAULT}"
DB_NAME="${DB_NAME:-orders}"
CU_MIN="${CU_MIN:-0.5}"
CU_MAX="${CU_MAX:-2.0}"

DB="databricks postgres"
P=(-p "$DATABRICKS_PROFILE" -o json)

log() { printf '\033[1;34m[%s]\033[0m %s\n' "$(date +%H:%M:%S)" "$*" >&2; }
die() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

# Wait until a branch reports READY (branches provision in a few seconds).
wait_for_branch() {
  local branch_path="$1" state
  for _ in $(seq 1 60); do
    state=$($DB get-branch "$branch_path" "${P[@]}" 2>/dev/null | jq -r '.status.current_state // empty')
    [[ "$state" == "READY" ]] && { log "branch READY: $branch_path"; return 0; }
    sleep 3
  done
  die "branch did not become READY: $branch_path"
}

# Resolve a branch's read-write endpoint once it is ACTIVE. Creating a branch
# auto-provisions a 'primary' endpoint, so we discover it rather than hardcode a
# name. Prints "<host> <endpoint_path>". Returns non-zero if none goes ACTIVE
# (callers use it in `x=$(...)` under `set -e`, so failure propagates).
resolve_endpoint() {
  local branch_path="$1" state host name
  for _ in $(seq 1 60); do
    read -r state host name < <($DB list-endpoints "$branch_path" "${P[@]}" 2>/dev/null \
      | jq -r '.[0] | "\(.status.current_state // "?") \(.status.hosts.host // "-") \(.name // "-")"')
    if [[ "$state" == "ACTIVE" && "$host" != "-" && "$name" != "-" ]]; then
      echo "$host $name"; return 0
    fi
    sleep 3
  done
  echo "endpoint did not become ACTIVE on branch: $branch_path" >&2
  return 1
}

# Print just the host for a branch's endpoint (used for logging).
endpoint_host() { resolve_endpoint "$1" | awk '{print $1}'; }

# Print a psql connection string for a branch. Generates a fresh 1-hour OAuth
# token each call — Lakebase has no static passwords to leak into CI logs.
conn_string() {
  local branch_id="$1" db="${2:-$DB_NAME}"
  local branch_path="${PROJECT}/branches/${branch_id}"
  local host endpoint_path token user
  read -r host endpoint_path < <(resolve_endpoint "$branch_path")
  [[ -n "${endpoint_path:-}" ]] || { echo "no active endpoint on $branch_path" >&2; return 1; }
  token=$($DB generate-database-credential "$endpoint_path" "${P[@]}" | jq -r '.token')
  user=$(databricks current-user me -p "$DATABRICKS_PROFILE" -o json | jq -r '.userName')
  echo "host=${host} port=5432 dbname=${db} user=${user} password=${token} sslmode=require"
}

# Same as conn_string but as a libpq/JDBC-friendly URL (used by pytest / Liquibase).
conn_url() {
  local branch_id="$1" db="${2:-$DB_NAME}"
  local branch_path="${PROJECT}/branches/${branch_id}"
  local host endpoint_path token user
  read -r host endpoint_path < <(resolve_endpoint "$branch_path")
  [[ -n "${endpoint_path:-}" ]] || { echo "no active endpoint on $branch_path" >&2; return 1; }
  token=$($DB generate-database-credential "$endpoint_path" "${P[@]}" | jq -r '.token')
  user=$(databricks current-user me -p "$DATABRICKS_PROFILE" -o json | jq -r '.userName')
  # URL-encode the user (emails contain @) and leave the token as-is (base64url safe).
  local enc_user="${user//@/%40}"
  echo "postgresql://${enc_user}:${token}@${host}:5432/${db}?sslmode=require"
}
