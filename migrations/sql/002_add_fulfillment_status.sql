-- 002_add_fulfillment_status.sql — the change under test in the PR.
--
-- This is the classic migration that silently breaks in a shared/empty dev DB
-- but is exercised properly here: adding a NOT NULL column to a table that
-- already has rows in production. The DEFAULT backfills existing orders; the
-- test suite asserts no row is left NULL.
-- Idempotent so re-running the pipeline is safe.

ALTER TABLE orders
    ADD COLUMN IF NOT EXISTS fulfillment_status VARCHAR(20) NOT NULL DEFAULT 'pending';

CREATE INDEX IF NOT EXISTS idx_orders_fulfillment_status
    ON orders (fulfillment_status);
