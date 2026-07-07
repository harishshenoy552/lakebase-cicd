#!/usr/bin/env bash
# bootstrap_production.sh — one-time setup of the production project.
#
# Creates the Lakebase project (which auto-provisions the production branch and
# primary endpoint), creates the application database, and seeds it with the
# baseline schema + sample data so that branches have realistic data to test
# against. Idempotent: safe to re-run.
#
# Usage: PROJECT=projects/orders-api ./scripts/bootstrap_production.sh

source "$(dirname "$0")/lib.sh"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ID="${PROJECT#projects/}"

if $DB get-project "$PROJECT" "${P[@]}" >/dev/null 2>&1; then
  log "project ${PROJECT} already exists."
else
  log "creating project ${PROJECT_ID}…"
  $DB create-project "$PROJECT_ID" \
    --json '{"spec": {"display_name": "Lakebase CI/CD demo"}}' "${P[@]}" >/dev/null
fi

wait_for_branch "${PROJECT}/branches/production"

ADMIN_CONN="$(conn_string production postgres)"
if ! psql "$ADMIN_CONN" -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  log "creating database ${DB_NAME}…"
  psql "$ADMIN_CONN" -c "CREATE DATABASE ${DB_NAME};"
fi

CONN="$(conn_string production "$DB_NAME")"
log "applying baseline schema + seed data…"
psql "$CONN" -v ON_ERROR_STOP=1 -f "$REPO_ROOT/migrations/sql/001_init_schema.sql"

log "production ready. Seeded rows:"
psql "$CONN" -c "SELECT count(*) AS orders FROM orders;"
