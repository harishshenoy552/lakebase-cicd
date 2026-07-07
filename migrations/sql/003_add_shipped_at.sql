-- 003_add_shipped_at.sql — record when an order shipped.
-- Nullable, so it applies cleanly to existing rows with no backfill needed.
-- Idempotent so re-running the pipeline is safe.

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMP;
