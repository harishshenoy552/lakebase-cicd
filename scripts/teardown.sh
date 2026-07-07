#!/usr/bin/env bash
# teardown.sh — delete an ephemeral branch, reclaiming its compute and
# copy-on-write storage. Safe to run whether the build passed or failed.
#
# Usage: BRANCH_ID=ci-pr-42 ./scripts/teardown.sh

source "$(dirname "$0")/lib.sh"
: "${BRANCH_ID:?set BRANCH_ID}"
BRANCH_PATH="${PROJECT}/branches/${BRANCH_ID}"

# Never delete production.
[[ "$BRANCH_ID" == "production" ]] && die "refusing to delete the production branch"

if ! $DB get-branch "$BRANCH_PATH" "${P[@]}" >/dev/null 2>&1; then
  log "branch ${BRANCH_ID} does not exist; nothing to tear down."
  exit 0
fi

# A branch created as protected must be unprotected before deletion.
$DB update-branch "$BRANCH_PATH" "spec.is_protected" \
  --json '{"spec": {"is_protected": false}}' "${P[@]}" >/dev/null 2>&1 || true

log "deleting branch ${BRANCH_ID} (cascades to its endpoints)…"
$DB delete-branch "$BRANCH_PATH" "${P[@]}" >/dev/null
log "branch ${BRANCH_ID} deleted."
