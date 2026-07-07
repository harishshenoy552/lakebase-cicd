-- assertions.sql — dependency-free equivalent of tests/test_orders.py.
--
-- Run with:  psql "<conn>" -v ON_ERROR_STOP=1 -f tests/assertions.sql
-- Each check RAISEs an exception (non-zero exit → failed build) if violated.
-- Used by scripts/test.sh as a fallback when pytest/psycopg2 can't be installed
-- (e.g. an offline or locked-down CI agent). Asserts the same properties as the
-- pytest suite.

DO $$
DECLARE
  v_is_nullable text;
  v_default     text;
  v_data_type   text;
  v_total       bigint;
  v_nulls       bigint;
  v_has_index   boolean;
BEGIN
  -- 1) fulfillment_status column exists, is NOT NULL, defaults to 'pending'
  SELECT data_type, is_nullable, column_default
    INTO v_data_type, v_is_nullable, v_default
  FROM information_schema.columns
  WHERE table_name = 'orders' AND column_name = 'fulfillment_status';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'FAIL: orders.fulfillment_status column was not created';
  END IF;
  IF v_is_nullable <> 'NO' THEN
    RAISE EXCEPTION 'FAIL: fulfillment_status must be NOT NULL (is_nullable=%)', v_is_nullable;
  END IF;
  IF v_default IS NULL OR v_default NOT LIKE '%pending%' THEN
    RAISE EXCEPTION 'FAIL: fulfillment_status default should be ''pending'' (got %)', v_default;
  END IF;

  -- 2) branch was data-inclusive AND every pre-existing row was backfilled
  SELECT count(*), count(*) FILTER (WHERE fulfillment_status IS NULL)
    INTO v_total, v_nulls FROM orders;
  IF v_total = 0 THEN
    RAISE EXCEPTION 'FAIL: expected seeded orders from production; branch was not data-inclusive';
  END IF;
  IF v_nulls > 0 THEN
    RAISE EXCEPTION 'FAIL: % pre-existing orders left with NULL fulfillment_status', v_nulls;
  END IF;

  -- 3) supporting index exists
  SELECT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_orders_fulfillment_status')
    INTO v_has_index;
  IF NOT v_has_index THEN
    RAISE EXCEPTION 'FAIL: expected index idx_orders_fulfillment_status';
  END IF;

  RAISE NOTICE 'PASS: fulfillment_status column NOT NULL/default OK; % orders, 0 NULLs; index present', v_total;
END $$;
