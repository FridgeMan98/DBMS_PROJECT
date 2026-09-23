-- =============================================================
-- 01_happy_path_test.sql
-- Happy Path: Full successful checkout flow
-- Verifies: order created, inventory deducted, payment logged,
--           shipment created, audit trail recorded
-- =============================================================

DO $$ BEGIN RAISE NOTICE '=== HAPPY PATH TEST ==='; END $$;

-- Record inventory BEFORE
DO $$
DECLARE
    v_qty_p1 INT; v_qty_p8 INT;
BEGIN
    SELECT stock_quantity INTO v_qty_p1 FROM inventory WHERE product_id = 1;
    SELECT stock_quantity INTO v_qty_p8 FROM inventory WHERE product_id = 8;
    RAISE NOTICE 'BEFORE — Product 1 stock: % | Product 8 stock: %', v_qty_p1, v_qty_p8;
END $$;

-- Place order: Customer 6 (Ananya, Chennai) buys headphones x1 + book x2
SELECT * FROM process_order_checkout(
    p_customer_id     := 6,
    p_cart_items      := ARRAY[ROW(1, 1), ROW(8, 2)]::cart_item[],
    p_payment_method  := 'net_banking',
    p_transaction_ref := 'TXN_HAPPY_001'
);

-- Record inventory AFTER
DO $$
DECLARE
    v_qty_p1 INT; v_qty_p8 INT;
BEGIN
    SELECT stock_quantity INTO v_qty_p1 FROM inventory WHERE product_id = 1;
    SELECT stock_quantity INTO v_qty_p8 FROM inventory WHERE product_id = 8;
    RAISE NOTICE 'AFTER  — Product 1 stock: % | Product 8 stock: %', v_qty_p1, v_qty_p8;
END $$;

-- Verify order exists and is approved
DO $$
DECLARE v_status VARCHAR(50); v_total NUMERIC;
BEGIN
    SELECT order_status, total_amount
    INTO   v_status, v_total
    FROM   orders ORDER BY order_id DESC LIMIT 1;

    IF v_status = 'approved' THEN
        RAISE NOTICE 'CHECK 1 PASSED: Order status = approved, total = ₹%', v_total;
    ELSE
        RAISE EXCEPTION 'CHECK 1 FAILED: Expected approved, got %', v_status;
    END IF;
END $$;

-- Verify payment recorded
DO $$
DECLARE v_pstatus VARCHAR(50);
BEGIN
    SELECT payment_status INTO v_pstatus
    FROM   payments WHERE order_id = (SELECT MAX(order_id) FROM orders);

    IF v_pstatus = 'completed' THEN
        RAISE NOTICE 'CHECK 2 PASSED: Payment status = completed';
    ELSE
        RAISE EXCEPTION 'CHECK 2 FAILED: Expected completed, got %', v_pstatus;
    END IF;
END $$;

-- Verify shipment created
DO $$
DECLARE v_ship_status VARCHAR(50); v_eta DATE;
BEGIN
    SELECT shipment_status, estimated_delivery
    INTO   v_ship_status, v_eta
    FROM   shipments WHERE order_id = (SELECT MAX(order_id) FROM orders);

    IF v_ship_status = 'pending' THEN
        RAISE NOTICE 'CHECK 3 PASSED: Shipment created, ETA = %', v_eta;
    ELSE
        RAISE EXCEPTION 'CHECK 3 FAILED: Shipment status = %', v_ship_status;
    END IF;
END $$;

-- Verify audit log has 'created' and 'approved' entries
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM   order_status_audit
    WHERE  order_id = (SELECT MAX(order_id) FROM orders)
      AND  new_status IN ('created', 'approved');

    IF v_count = 2 THEN
        RAISE NOTICE 'CHECK 4 PASSED: Audit log has 2 entries (created + approved)';
    ELSE
        RAISE EXCEPTION 'CHECK 4 FAILED: Expected 2 audit entries, got %', v_count;
    END IF;
END $$;

-- Verify inventory_audit has 2 deduction entries
DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM   inventory_audit
    WHERE  order_id = (SELECT MAX(order_id) FROM orders)
      AND  action = 'deduction';

    IF v_count = 2 THEN
        RAISE NOTICE 'CHECK 5 PASSED: Inventory audit has 2 deduction records';
    ELSE
        RAISE EXCEPTION 'CHECK 5 FAILED: Expected 2 inventory audit entries, got %', v_count;
    END IF;
END $$;

\echo '  [OK] Happy path test complete.'
