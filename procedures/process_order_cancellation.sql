-- =============================================================
-- 03_process_order_cancellation.sql
-- Stored Procedure: process_order_cancellation
--
-- Reverse-logistics pipeline:
--   1. Validate order exists and is cancellable
--   2. Replenish inventory for each order item
--   3. Log replenishment in inventory_audit
--   4. Mark payment as refunded
--   5. Update order status to 'cancelled' (audit trigger fires)
--   6. Update shipment status to 'returned' if applicable
--
-- Non-cancellable statuses: 'shipped', 'delivered', 'cancelled'
-- =============================================================

CREATE OR REPLACE FUNCTION process_order_cancellation(
    p_order_id  INT
)
RETURNS TABLE (
    result_order_id     INT,
    result_status       VARCHAR(50),
    result_message      TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_current_status    VARCHAR(50);
    v_item              RECORD;
    v_inventory_id      INT;
    v_qty_before        INT;
BEGIN
    -- --------------------------------------------------------
    -- STEP 1: Fetch and validate order
    -- --------------------------------------------------------
    SELECT order_status INTO v_current_status
    FROM   orders
    WHERE  order_id = p_order_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Order #% does not exist.', p_order_id;
    END IF;

    IF v_current_status IN ('shipped', 'delivered', 'cancelled') THEN
        RAISE EXCEPTION
            'Order #% cannot be cancelled. Current status: %.', p_order_id, v_current_status;
    END IF;

    -- --------------------------------------------------------
    -- STEP 2: Replenish inventory for each item
    -- --------------------------------------------------------
    FOR v_item IN
        SELECT oi.product_id, oi.quantity
        FROM   order_items oi
        WHERE  oi.order_id = p_order_id
    LOOP
        SELECT inventory_id, stock_quantity
        INTO   v_inventory_id, v_qty_before
        FROM   inventory
        WHERE  product_id = v_item.product_id
        FOR UPDATE;

        UPDATE inventory
        SET    stock_quantity = stock_quantity + v_item.quantity,
               last_updated       = NOW()
        WHERE  inventory_id = v_inventory_id;

        -- Log replenishment
        INSERT INTO inventory_audit (
            inventory_id,
            product_id,
            order_id,
            quantity_before,
            quantity_deducted,
            quantity_after,
            action
        ) VALUES (
            v_inventory_id,
            v_item.product_id,
            p_order_id,
            v_qty_before,
            -v_item.quantity,         -- negative = replenishment
            v_qty_before + v_item.quantity,
            'replenishment'
        );
    END LOOP;

    -- --------------------------------------------------------
    -- STEP 3: Refund payment
    -- --------------------------------------------------------
    UPDATE payments
    SET    payment_status = 'refunded'
    WHERE  order_id = p_order_id
      AND  payment_status = 'completed';

    -- --------------------------------------------------------
    -- STEP 4: Cancel order (audit trigger fires)
    -- --------------------------------------------------------
    UPDATE orders
    SET    order_status = 'cancelled'
    WHERE  order_id = p_order_id;

    -- --------------------------------------------------------
    -- STEP 5: Update shipment if exists
    -- --------------------------------------------------------
    UPDATE shipments
    SET    shipment_status = 'returned'
    WHERE  order_id = p_order_id
      AND  shipment_status IN ('pending', 'dispatched');

    -- --------------------------------------------------------
    -- Return result
    -- --------------------------------------------------------
    RETURN QUERY
    SELECT p_order_id,
           'cancelled'::VARCHAR(50),
           format('Order #%s successfully cancelled. Inventory replenished. Refund initiated.',
                  p_order_id)::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE;
END;
$$;

\echo '  [OK] process_order_cancellation() created.'