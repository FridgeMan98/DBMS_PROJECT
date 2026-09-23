-- =============================================================
-- 01_isolation_level_config.sql
-- Demonstrates explicit transaction blocks with isolation levels
-- Shows: REPEATABLE READ, SERIALIZABLE, and SELECT FOR UPDATE
-- =============================================================

-- =============================================================
-- DEMO A: REPEATABLE READ — Checkout transaction
-- Prevents: dirty reads, non-repeatable reads
-- Use case: Standard multi-item checkout
-- =============================================================
DO $$
BEGIN
    RAISE NOTICE '--- DEMO A: REPEATABLE READ checkout block ---';
END $$;

BEGIN;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- Within this block, any row read at the start remains
    -- consistent even if another transaction modifies it.
    -- The inventory trigger + SELECT FOR UPDATE inside
    -- process_order_checkout handles the actual locking.

    SELECT process_order_checkout(
        p_customer_id     := 1,
        p_cart_items      := ARRAY[ROW(1, 1), ROW(2, 2)]::cart_item[],
        p_payment_method  := 'credit_card',
        p_transaction_ref := 'TXN_DEMO_A_001'
    );

COMMIT;


-- =============================================================
-- DEMO B: SERIALIZABLE — Highest isolation for critical ops
-- Prevents: phantom reads, serialization anomalies
-- Use case: Flash sales, limited stock items
-- =============================================================
DO $$
BEGIN
    RAISE NOTICE '--- DEMO B: SERIALIZABLE checkout block ---';
END $$;

BEGIN;
    SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

    SELECT process_order_checkout(
        p_customer_id     := 2,
        p_cart_items      := ARRAY[ROW(3, 1)]::cart_item[],
        p_payment_method  := 'upi',
        p_transaction_ref := 'TXN_DEMO_B_001'
    );

COMMIT;


-- =============================================================
-- DEMO C: Manual ROLLBACK — Payment failure scenario
-- =============================================================
DO $$
BEGIN
    RAISE NOTICE '--- DEMO C: Manual ROLLBACK on payment failure ---';
END $$;

BEGIN;
    SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;

    -- Simulate order creation
    INSERT INTO orders (customer_id, order_status, total_amount)
    VALUES (3, 'created', 549.00);

    -- Simulate payment gateway failure → rollback everything
    ROLLBACK;

DO $$
BEGIN
    RAISE NOTICE 'DEMO C: Transaction rolled back. No data committed.';
END $$;


-- =============================================================
-- DEMO D: Explicit SELECT FOR UPDATE locking
-- Shows how we prevent two sessions from reading the same
-- inventory row and both thinking stock is available
-- =============================================================
DO $$
BEGIN
    RAISE NOTICE '--- DEMO D: SELECT FOR UPDATE lock demonstration ---';
END $$;

BEGIN;
    -- Session 1 acquires lock on product 10 inventory
    -- Session 2 trying the same will WAIT until this commits
    SELECT stock_quantity
    FROM   inventory
    WHERE  product_id = 10
    FOR UPDATE;

    -- Do work...
    UPDATE inventory
    SET    stock_quantity = stock_quantity - 1,
           last_updated = NOW()
    WHERE  product_id = 10;

COMMIT;

\echo '  [OK] Isolation level demos executed.'
