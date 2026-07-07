#!/usr/bin/env bash
# test.sh — run the test suite against a branch's database.
#
# Exports DATABASE_URL for pytest, then runs tests/. Because the branch was
# seeded from production, these tests exercise the migration against real data
# shape (row counts, existing values, constraints) — not an empty schema.
#
# Usage: BRANCH_ID=ci-pr-42 ./scripts/test.sh

source "$(dirname "$0")/lib.sh"
: "${BRANCH_ID:?set BRANCH_ID}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

DATABASE_URL="$(conn_url "$BRANCH_ID" "$DB_NAME")"
export DATABASE_URL

log "running pytest against branch ${BRANCH_ID}…"
python3 -m pytest "$REPO_ROOT/tests/" -v
