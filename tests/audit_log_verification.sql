-- =============================================================
-- 04_audit_log_verification.sql
-- Audit Trail Verification
-- Verifies: every order lifecycle step is logged with timestamps,
--           inventory deductions and replenishments are recorded,
--           immutability (no updates/deletes possible)
-- =============================================================

DO $$ BEGIN RAISE NOTICE '=== AUDIT LOG VERIFICATION ==='; END $$;


-- =============================================================
-- REPORT 1: Full order status audit trail
-- =============================================================
DO $$ BEGIN RAISE NOTICE '--- Order Status Audit Trail ---'; END $$;

SELECT
    a.audit_id,
    a.order_id,
    COALESCE(a.old_status::TEXT, '(none)') AS from_status,
    a.new_status                     AS to_status,
    a.changed_at,
    a.changed_by_user
FROM   order_status_audit a
ORDER  BY a.order_id, a.changed_at;


-- =============================================================
-- REPORT 2: Inventory audit trail
-- =============================================================
DO $$ BEGIN RAISE NOTICE '--- Inventory Audit Trail ---'; END $$;

SELECT
    ia.audit_id,
    ia.product_id,
    p.product_name,
    ia.order_id,
    ia.quantity_before,
    ia.quantity_deducted,
    ia.quantity_after,
    ia.action,
    ia.changed_at
FROM   inventory_audit ia
JOIN   products p ON p.product_id = ia.product_id
ORDER  BY ia.changed_at;


-- =============================================================
-- REPORT 3: Current inventory snapshot
-- =============================================================
DO $$ BEGIN RAISE NOTICE '--- Current Inventory Snapshot ---'; END $$;

SELECT
    i.product_id,
    p.product_name,
    i.stock_quantity,
    i.reorder_level,
    CASE WHEN i.stock_quantity <= i.reorder_level
         THEN '⚠ LOW STOCK' ELSE 'OK' END AS stock_alert,
    i.last_updated
FROM   inventory i
JOIN   products p ON p.product_id = i.product_id
ORDER  BY i.product_id;


-- =============================================================
-- REPORT 4: Order summary with payment + shipment
-- =============================================================
DO $$ BEGIN RAISE NOTICE '--- Order Summary Report ---'; END $$;

SELECT
    o.order_id,
    c.first_name || ' ' || c.last_name   AS customer,
    o.order_status,
    o.total_amount,
    pay.payment_method,
    pay.payment_status,
    sh.shipment_status,
    sh.estimated_delivery,
    o.placed_at
FROM   orders o
JOIN   customers c  ON c.customer_id  = o.customer_id
LEFT JOIN payments pay ON pay.order_id = o.order_id
LEFT JOIN shipments sh  ON sh.order_id  = o.order_id
ORDER  BY o.order_id;


-- =============================================================
-- VERIFICATION: Immutability check
-- Audit tables should reject DELETE and UPDATE
-- (Enforce via REVOKE or row-level security in production)
-- =============================================================
DO $$
BEGIN
    RAISE NOTICE '--- Immutability Verification ---';
    BEGIN
        DELETE FROM order_status_audit WHERE audit_id = 1;
        RAISE NOTICE 'WARNING: Audit record deleted — add RULE or RLS to prevent this!';
    EXCEPTION
        WHEN insufficient_privilege THEN
            RAISE NOTICE 'IMMUTABILITY CHECK PASSED: DELETE on audit table denied.';
        WHEN OTHERS THEN
            RAISE NOTICE 'NOTE: To enforce immutability, run the following:';
            RAISE NOTICE '  REVOKE DELETE, UPDATE ON order_status_audit FROM PUBLIC;';
            RAISE NOTICE '  REVOKE DELETE, UPDATE ON inventory_audit FROM PUBLIC;';
    END;
END $$;


-- =============================================================
-- VERIFICATION: Audit count consistency
-- Every order should have at least one audit entry
-- =============================================================
DO $$
DECLARE v_orphaned INT;
BEGIN
    SELECT COUNT(*) INTO v_orphaned
    FROM   orders o
    WHERE  NOT EXISTS (
        SELECT 1 FROM order_status_audit a WHERE a.order_id = o.order_id
    );

    IF v_orphaned = 0 THEN
        RAISE NOTICE 'AUDIT CONSISTENCY CHECK PASSED: All orders have audit entries.';
    ELSE
        RAISE NOTICE 'WARNING: % orders have no audit entries!', v_orphaned;
    END IF;
END $$;

\echo '  [OK] Audit log verification complete.'
