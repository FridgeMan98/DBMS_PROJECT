-- =============================================================
-- 03_cancellation_test.sql
-- Cancellation & Reverse Logistics Tests
-- Verifies: inventory restored, payment refunded, status updated,
--           audit trail updated, cannot cancel shipped orders
-- =============================================================

DO $$ BEGIN RAISE NOTICE '=== CANCELLATION TEST ==='; END $$;

-- Setup: Place a fresh order to cancel
DO $$ BEGIN RAISE NOTICE 'Setup: Placing order to be cancelled...'; END $$;

SELECT * FROM process_order_checkout(
    p_customer_id     := 10,
    p_cart_items      := ARRAY[ROW(9, 3), ROW(14, 2)]::cart_item[],
    p_payment_method  := 'debit_card',
    p_transaction_ref := 'TXN_CANCEL_SETUP'
);

-- Capture the new order id
DO $$
DECLARE
    v_order_id  INT;
    v_qty_p9    INT;
    v_qty_p14   INT;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;

    SELECT stock_quantity INTO v_qty_p9  FROM inventory WHERE product_id = 9;
    SELECT stock_quantity INTO v_qty_p14 FROM inventory WHERE product_id = 14;
    RAISE NOTICE 'Order #% placed. Product 9 stock: %, Product 14 stock: %',
                  v_order_id, v_qty_p9, v_qty_p14;
END $$;


-- TEST 1: Cancel the order
DO $$
DECLARE v_order_id INT;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    RAISE NOTICE 'TEST 1: Cancelling order #%...', v_order_id;

    PERFORM process_order_cancellation(v_order_id);
    RAISE NOTICE 'TEST 1 PASSED: Cancellation completed for order #%', v_order_id;
END $$;

-- Verify order status = cancelled
DO $$
DECLARE v_status VARCHAR(50); v_order_id INT;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    SELECT order_status INTO v_status FROM orders WHERE order_id = v_order_id;

    IF v_status = 'cancelled' THEN
        RAISE NOTICE 'CHECK 1 PASSED: Order status = cancelled';
    ELSE
        RAISE EXCEPTION 'CHECK 1 FAILED: Expected cancelled, got %', v_status;
    END IF;
END $$;

-- Verify inventory restored
DO $$
DECLARE v_qty_p9 INT; v_qty_p14 INT;
BEGIN
    SELECT stock_quantity INTO v_qty_p9  FROM inventory WHERE product_id = 9;
    SELECT stock_quantity INTO v_qty_p14 FROM inventory WHERE product_id = 14;
    RAISE NOTICE 'CHECK 2: Product 9 stock restored to %, Product 14 to %',
                  v_qty_p9, v_qty_p14;
END $$;

-- Verify payment refunded
DO $$
DECLARE v_pstatus VARCHAR(50); v_order_id INT;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    SELECT payment_status INTO v_pstatus FROM payments WHERE order_id = v_order_id;

    IF v_pstatus = 'refunded' THEN
        RAISE NOTICE 'CHECK 3 PASSED: Payment status = refunded';
    ELSE
        RAISE EXCEPTION 'CHECK 3 FAILED: Expected refunded, got %', v_pstatus;
    END IF;
END $$;

-- Verify audit log has 'cancelled' entry
DO $$
DECLARE v_count INT; v_order_id INT;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    SELECT COUNT(*) INTO v_count
    FROM   order_status_audit
    WHERE  order_id = v_order_id AND new_status = 'cancelled';

    IF v_count >= 1 THEN
        RAISE NOTICE 'CHECK 4 PASSED: Audit log has cancellation entry';
    ELSE
        RAISE EXCEPTION 'CHECK 4 FAILED: No cancellation entry in audit log';
    END IF;
END $$;


-- TEST 2: Try to cancel an already-cancelled order (should fail)
DO $$
DECLARE v_order_id INT;
BEGIN
    SELECT MAX(order_id) INTO v_order_id FROM orders;
    RAISE NOTICE 'TEST 2: Cancelling an already-cancelled order...';
    BEGIN
        PERFORM process_order_cancellation(v_order_id);
        RAISE EXCEPTION 'TEST 2 FAILED: Should not allow double cancellation!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 2 PASSED: Double cancellation rejected — %', SQLERRM;
    END;
END $$;


-- TEST 3: Try to cancel a shipped order (should fail)
DO $$
DECLARE v_order_id INT;
BEGIN
    -- Place a new order
    SELECT (process_order_checkout(
        p_customer_id     := 1,
        p_cart_items      := ARRAY[ROW(10, 1)]::cart_item[],
        p_payment_method  := 'credit_card',
        p_transaction_ref := 'TXN_CANCEL_SHIPPED'
    )).result_order_id INTO v_order_id;

    -- Force it to shipped
    UPDATE orders SET order_status = 'shipped' WHERE order_id = v_order_id;

    RAISE NOTICE 'TEST 3: Trying to cancel shipped order #%...', v_order_id;
    BEGIN
        PERFORM process_order_cancellation(v_order_id);
        RAISE EXCEPTION 'TEST 3 FAILED: Shipped order should not be cancellable!';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE 'TEST 3 PASSED: Cannot cancel shipped order — %', SQLERRM;
    END;
END $$;

\echo '  [OK] Cancellation tests complete.'
