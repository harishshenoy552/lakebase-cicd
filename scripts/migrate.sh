#!/usr/bin/env bash
# migrate.sh — apply schema migrations to a branch.
#
# Two modes, selected by MIGRATION_TOOL:
#   sql       (default) apply every migrations/sql/*.sql file in order via psql
#   liquibase run `liquibase update` against the Liquibase changelog
#
# Usage:
#   BRANCH_ID=ci-pr-42 ./scripts/migrate.sh                 # plain SQL
#   BRANCH_ID=ci-pr-42 MIGRATION_TOOL=liquibase ./scripts/migrate.sh
#
# For promotion, callers pass BRANCH_ID=production (see promote.sh).

source "$(dirname "$0")/lib.sh"
: "${BRANCH_ID:?set BRANCH_ID}"
MIGRATION_TOOL="${MIGRATION_TOOL:-sql}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Ensure the target database exists (a fresh production branch only has `postgres`).
ensure_database() {
  local admin_conn
  admin_conn="$(conn_string "$BRANCH_ID" postgres)"
  if ! psql "$admin_conn" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
    log "creating database ${DB_NAME}…"
    psql "$admin_conn" -c "CREATE DATABASE ${DB_NAME};"
  fi
}

ensure_database

case "$MIGRATION_TOOL" in
  sql)
    CONN="$(conn_string "$BRANCH_ID" "$DB_NAME")"
    shopt -s nullglob
    files=("$REPO_ROOT"/migrations/sql/*.sql)
    (( ${#files[@]} )) || die "no .sql files in migrations/sql/"
    for f in "${files[@]}"; do
      log "applying $(basename "$f")…"
      psql "$CONN" -v ON_ERROR_STOP=1 -f "$f"
    done
    ;;
  liquibase)
    command -v liquibase >/dev/null || die "liquibase not on PATH"
    read -r host endpoint_path < <(resolve_endpoint "${PROJECT}/branches/${BRANCH_ID}")
    [[ -n "${endpoint_path:-}" ]] || die "no active endpoint on ${BRANCH_ID}"
    user=$(databricks current-user me -p "$DATABRICKS_PROFILE" -o json | jq -r '.userName')
    token=$($DB generate-database-credential "$endpoint_path" "${P[@]}" | jq -r '.token')
    log "running liquibase update against ${DB_NAME}…"
    liquibase \
      --url="jdbc:postgresql://${host}:5432/${DB_NAME}?sslmode=require" \
      --username="$user" \
      --password="$token" \
      --changeLogFile="$REPO_ROOT/liquibase/changelog/db.changelog-master.xml" \
      update
    ;;
  *) die "unknown MIGRATION_TOOL: $MIGRATION_TOOL (expected sql|liquibase)" ;;
esac

log "migrations applied to ${BRANCH_ID}/${DB_NAME}"
