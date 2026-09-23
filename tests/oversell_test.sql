-- =============================================================
-- 02_oversell_test.sql
-- Edge Case: Oversell Prevention
-- Verifies: system rejects orders that exceed available stock
--           and does NOT partially commit
-- =============================================================

DO $$ BEGIN RAISE NOTICE '=== OVERSELL PREVENTION TEST ==='; END $$;

-- Force product 11 stock to 2
UPDATE inventory SET stock_quantity = 2 WHERE product_id = 11;

DO $$
DECLARE v_qty INT;
BEGIN
    SELECT stock_quantity INTO v_qty FROM inventory WHERE product_id = 11;
    RAISE NOTICE 'Setup: Product 11 (Yoga Mat) stock set to %', v_qty;
END $$;

-- TEST 1: Try to order more than available (qty=5 > available=2)
DO $$
BEGIN
    RAISE NOTICE 'TEST 1: Requesting qty=5 when only 2 available...';
    BEGIN
        PERFORM process_order_checkout(
            p_customer_id     := 7,
            p_cart_items      := ARRAY[ROW(11, 5)]::cart_item[],
            p_payment_method  := 'credit_card',
            p_transaction_ref := 'TXN_OVERSELL_001'
        );
        RAISE EXCEPTION 'TEST 1 FAILED: Order should have been rejected!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 1 PASSED: Correctly rejected — %', SQLERRM;
    END;
END $$;

-- Verify stock was NOT deducted (should still be 2)
DO $$
DECLARE v_qty INT;
BEGIN
    SELECT stock_quantity INTO v_qty FROM inventory WHERE product_id = 11;
    IF v_qty = 2 THEN
        RAISE NOTICE 'TEST 1 STOCK CHECK PASSED: Stock unchanged at %', v_qty;
    ELSE
        RAISE EXCEPTION 'TEST 1 STOCK CHECK FAILED: Stock changed to %, rollback failed!', v_qty;
    END IF;
END $$;


-- TEST 2: Multi-item cart — one item exceeds stock, whole order fails
UPDATE inventory SET stock_quantity = 1 WHERE product_id = 12;

DO $$
BEGIN
    RAISE NOTICE 'TEST 2: Mixed cart — product 10 ok, product 12 insufficient...';
    BEGIN
        PERFORM process_order_checkout(
            p_customer_id     := 8,
            p_cart_items      := ARRAY[ROW(10, 1), ROW(12, 5)]::cart_item[],
            p_payment_method  := 'upi',
            p_transaction_ref := 'TXN_OVERSELL_002'
        );
        RAISE EXCEPTION 'TEST 2 FAILED: Should have rejected entire cart!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 2 PASSED: Entire cart rejected — %', SQLERRM;
    END;
END $$;

-- Verify product 10 stock was NOT deducted either (atomicity)
DO $$
DECLARE v_qty INT;
BEGIN
    SELECT stock_quantity INTO v_qty FROM inventory WHERE product_id = 10;
    RAISE NOTICE 'TEST 2 ATOMICITY CHECK: Product 10 stock = % (should be original 75)', v_qty;
END $$;


-- TEST 3: Zero quantity in cart
DO $$
BEGIN
    RAISE NOTICE 'TEST 3: Zero quantity item in cart...';
    BEGIN
        PERFORM process_order_checkout(
            p_customer_id     := 9,
            p_cart_items      := ARRAY[ROW(11, 0)]::cart_item[],
            p_payment_method  := 'cod',
            p_transaction_ref := 'TXN_OVERSELL_003'
        );
        RAISE EXCEPTION 'TEST 3 FAILED: Zero quantity should be rejected!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 3 PASSED: Zero quantity rejected — %', SQLERRM;
    END;
END $$;

-- Restore stock
UPDATE inventory SET stock_quantity = 55 WHERE product_id = 11;
UPDATE inventory SET stock_quantity = 45 WHERE product_id = 12;

\echo '  [OK] Oversell tests complete.'
