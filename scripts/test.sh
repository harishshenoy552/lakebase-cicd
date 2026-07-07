#!/usr/bin/env bash
# test.sh — run the test suite against a branch's database.
#
# Prefers the pytest suite (tests/test_orders.py). If pytest/psycopg2 aren't
# importable and can't be installed (e.g. an offline or locked-down CI agent),
# falls back to the dependency-free SQL assertions (tests/assertions.sql), which
# check the same properties using only psql. Either way, the tests exercise the
# migration against the branch's real, production-seeded rows.
#
# Usage: BRANCH_ID=ci-pr-42 ./scripts/test.sh

source "$(dirname "$0")/lib.sh"
: "${BRANCH_ID:?set BRANCH_ID}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="${PYTHON:-python3}"

have_pytest() { "$PY" -c 'import psycopg2, pytest' >/dev/null 2>&1; }

if ! have_pytest; then
  # Best-effort install (no-op offline); ignore failure and let the check below decide.
  "$PY" -m pip install -q -r "$REPO_ROOT/tests/requirements.txt" >/dev/null 2>&1 || true
fi

if have_pytest; then
  log "running pytest against branch ${BRANCH_ID}…"
  DATABASE_URL="$(conn_url "$BRANCH_ID" "$DB_NAME")" \
    "$PY" -m pytest "$REPO_ROOT/tests/" -v
else
  log "pytest/psycopg2 unavailable (offline agent?) — verifying via psql assertions instead…"
  CONN="$(conn_string "$BRANCH_ID" "$DB_NAME")"
  psql "$CONN" -v ON_ERROR_STOP=1 -f "$REPO_ROOT/tests/assertions.sql"
fi
