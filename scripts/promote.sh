#!/usr/bin/env bash
# promote.sh — apply the reviewed migration to the protected production branch.
#
# Runs only after the migration has passed CI on an ephemeral branch AND a DBA
# has approved (the DBA gate lives in the Jenkinsfile). This applies the exact
# same migration artifact to production/primary.
#
# Usage: ./scripts/promote.sh                 # plain SQL
#        MIGRATION_TOOL=liquibase ./scripts/promote.sh

source "$(dirname "$0")/lib.sh"

log "promoting migrations to the production branch…"
BRANCH_ID=production MIGRATION_TOOL="${MIGRATION_TOOL:-sql}" \
  "$(dirname "$0")/migrate.sh"
log "production updated."
