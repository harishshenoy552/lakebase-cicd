"""Tests that run against a Lakebase branch (not an empty schema).

The branch is a copy-on-write clone of production, so these assertions exercise
the migration against real, pre-existing rows — the conditions that actually
break migrations in production.

Connection comes from DATABASE_URL, exported by scripts/test.sh.
"""
import os
import psycopg2
import pytest


@pytest.fixture(scope="module")
def conn():
    url = os.environ["DATABASE_URL"]
    c = psycopg2.connect(url)
    yield c
    c.close()


def test_fulfillment_status_column_exists(conn):
    """Migration 002 must have added the column."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT data_type, is_nullable, column_default
            FROM information_schema.columns
            WHERE table_name = 'orders' AND column_name = 'fulfillment_status'
            """
        )
        row = cur.fetchone()
    assert row is not None, "fulfillment_status column was not created"
    data_type, is_nullable, default = row
    assert data_type == "character varying"
    assert is_nullable == "NO", "column must be NOT NULL"
    assert default is not None and "pending" in default


def test_existing_rows_were_backfilled(conn):
    """The pre-existing production rows must have been backfilled with the default.

    This is the assertion that fails on a naive `ADD COLUMN NOT NULL` without a
    default — and the reason testing against real data (not an empty table)
    matters.
    """
    with conn.cursor() as cur:
        cur.execute("SELECT count(*) FROM orders")
        total = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM orders WHERE fulfillment_status IS NULL")
        nulls = cur.fetchone()[0]
    assert total > 0, "expected seeded orders from production; branch was not data-inclusive"
    assert nulls == 0, f"{nulls} pre-existing orders left with NULL fulfillment_status"


def test_index_present(conn):
    """The supporting index should exist so status lookups stay fast."""
    with conn.cursor() as cur:
        cur.execute(
            "SELECT 1 FROM pg_indexes WHERE indexname = 'idx_orders_fulfillment_status'"
        )
        assert cur.fetchone() is not None, "expected idx_orders_fulfillment_status"
