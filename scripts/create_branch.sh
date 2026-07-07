#!/usr/bin/env bash
# create_branch.sh — create an ephemeral, copy-on-write database branch for a PR.
#
# Usage: BRANCH_ID=ci-pr-42 ./scripts/create_branch.sh
#
# The branch is an instant copy-on-write snapshot of production, so it includes
# real data at production scale but costs nothing extra until rows diverge.
# Creating a branch auto-provisions a read-write endpoint that scales to zero
# when idle, so there is no separate endpoint to create.

source "$(dirname "$0")/lib.sh"
: "${BRANCH_ID:?set BRANCH_ID, e.g. ci-pr-42}"

BRANCH_PATH="${PROJECT}/branches/${BRANCH_ID}"

if $DB get-branch "$BRANCH_PATH" "${P[@]}" >/dev/null 2>&1; then
  log "branch already exists, reusing: $BRANCH_PATH"
else
  log "creating branch ${BRANCH_ID} from production (copy-on-write)…"
  # no_expiry=true: the branch persists until teardown deletes it. (To make
  # abandoned branches self-clean, drop no_expiry and pass a "ttl" instead.)
  $DB create-branch "$PROJECT" "$BRANCH_ID" \
    --json "{\"spec\": {\"source_branch\": \"${PROJECT}/branches/production\", \"no_expiry\": true}}" \
    "${P[@]}" >/dev/null
fi

wait_for_branch "$BRANCH_PATH"
HOST=$(endpoint_host "$BRANCH_PATH")
log "branch ready → ${BRANCH_ID} @ ${HOST} (scales to zero when idle)"
