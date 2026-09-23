-- =============================================================
-- 01_inventory_deduction_trigger.sql
-- Fires AFTER INSERT on order_items.
-- Deducts stock from the nearest warehouse and logs the change.
-- Raises an exception if stock is insufficient.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_deduct_inventory()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_warehouse_state  CHAR(2);
    v_seller_state     CHAR(2);
    v_stock_before     INT;
    v_inventory_id     INT;
BEGIN
    -- Determine the seller's state (acts as the primary warehouse)
    SELECT s.state_code
      INTO v_seller_state
      FROM orders o
      JOIN sellers s ON s.seller_id = o.seller_id
     WHERE o.order_id = NEW.order_id;

    -- Try to find inventory in seller's state first, else any warehouse with enough stock
    SELECT inv.inventory_id,
           inv.warehouse_state,
           inv.stock_quantity
      INTO v_inventory_id,
           v_warehouse_state,
           v_stock_before
      FROM inventory inv
     WHERE inv.product_id = NEW.product_id
       AND inv.stock_quantity >= NEW.quantity
     ORDER BY
           (inv.warehouse_state = v_seller_state) DESC,
           inv.stock_quantity DESC
     LIMIT 1
       FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Insufficient stock for product_id=%. Requested: %, Available: 0 in any warehouse.',
            NEW.product_id, NEW.quantity;
    END IF;

    -- Deduct stock
    UPDATE inventory
       SET stock_quantity = stock_quantity - NEW.quantity,
           last_updated   = NOW()
     WHERE inventory_id = v_inventory_id;

    -- Log to inventory_audit
    INSERT INTO inventory_audit (
        inventory_id,
        product_id,
        order_id,
        quantity_before,
        quantity_deducted,
        quantity_after,
        action,
        changed_by_user
    ) VALUES (
        v_inventory_id,
        NEW.product_id,
        NEW.order_id,
        v_stock_before,
        NEW.quantity,
        v_stock_before - NEW.quantity,
        'deduction',
        current_user
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_deduct_inventory ON order_items;

CREATE TRIGGER trg_deduct_inventory
AFTER INSERT ON order_items
FOR EACH ROW
EXECUTE FUNCTION fn_deduct_inventory();

\echo '--> Inventory deduction trigger created.'