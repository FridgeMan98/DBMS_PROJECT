-- =============================================================
-- 01_process_order_checkout.sql
-- Stored Procedure: process_order_checkout
--
-- Orchestrates the full checkout pipeline atomically:
--   1. Validate customer exists and is active
--   2. Validate each cart item (product active, stock available)
--   3. Create the order record
--   4. Insert order_items (triggers inventory deduction)
--   5. Record payment
--   6. Approve the order (triggers audit log)
--   7. Create shipment record
--
-- Usage:
--   SELECT process_order_checkout(
--       p_customer_id  := 1,
--       p_cart_items   := ARRAY[ROW(1, 2), ROW(3, 1)]::cart_item[],
--       p_payment_method := 'credit_card',
--       p_transaction_ref := 'TXN_ABC123'
--   );
-- =============================================================

-- Define cart_item composite type (product_id, quantity)
DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'cart_item') THEN
        CREATE TYPE cart_item AS (
            product_id  INT,
            quantity    INT
        );
    END IF;
END $$;


CREATE OR REPLACE FUNCTION process_order_checkout(
    p_customer_id       INT,
    p_cart_items        cart_item[],
    p_payment_method    VARCHAR(50),
    p_transaction_ref   VARCHAR(255) DEFAULT NULL
)
RETURNS TABLE (
    result_order_id     INT,
    result_status       VARCHAR(50),
    result_total        NUMERIC(14,2),
    result_message      TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_order_id          INT;
    v_total_amount      NUMERIC(14,2) := 0;
    v_item              cart_item;
    v_unit_price        NUMERIC(12,2);
    v_available_qty     INT;
    v_product_active    BOOLEAN;
    v_seller_id         INT;
    v_delivery_date     DATE;
    v_customer_state    CHAR(2);
    v_seller_state      CHAR(2);
    v_shipping_addr     TEXT;
BEGIN
    -- --------------------------------------------------------
    -- STEP 1: Validate customer & fetch address
    -- --------------------------------------------------------
    SELECT format('%s, %s, %s - %s', address_line, city, state_code, pincode)
    INTO v_shipping_addr
    FROM customers
    WHERE customer_id = p_customer_id AND is_active = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Customer % not found or inactive.', p_customer_id;
    END IF;


    -- --------------------------------------------------------
    -- STEP 2: Validate cart is not empty
    -- --------------------------------------------------------
    IF array_length(p_cart_items, 1) IS NULL THEN
        RAISE EXCEPTION 'Cart is empty. Cannot process checkout.';
    END IF;

    -- --------------------------------------------------------
    -- STEP 3: Validate each cart item & compute total
    -- --------------------------------------------------------
    FOREACH v_item IN ARRAY p_cart_items LOOP
        IF v_item.quantity <= 0 THEN
            RAISE EXCEPTION 'Invalid quantity % for product_id=%.',
                v_item.quantity, v_item.product_id;
        END IF;

        SELECT unit_price, is_active, seller_id INTO v_unit_price, v_product_active, v_seller_id
        FROM products WHERE product_id = v_item.product_id;

        SELECT COALESCE(SUM(stock_quantity), 0) INTO v_available_qty
        FROM inventory WHERE product_id = v_item.product_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Product % does not exist.', v_item.product_id;
        END IF;

        IF NOT v_product_active THEN
            RAISE EXCEPTION 'Product % is no longer available.', v_item.product_id;
        END IF;

        IF v_available_qty < v_item.quantity THEN
            RAISE EXCEPTION
                'Insufficient stock for product_id=%. Available: %, Requested: %.',
                v_item.product_id, v_available_qty, v_item.quantity;
        END IF;

        v_total_amount := v_total_amount + (v_unit_price * v_item.quantity);
    END LOOP;

    -- --------------------------------------------------------
    -- STEP 4: Create the order
    -- --------------------------------------------------------
    INSERT INTO orders (customer_id, seller_id, order_status, total_amount, shipping_addr)
    VALUES (p_customer_id, v_seller_id, 'created', v_total_amount, v_shipping_addr)
    RETURNING order_id INTO v_order_id;

    -- --------------------------------------------------------
    -- STEP 5: Insert order items (inventory trigger fires here)
    -- --------------------------------------------------------
    FOREACH v_item IN ARRAY p_cart_items LOOP
        SELECT unit_price INTO v_unit_price
        FROM   products WHERE product_id = v_item.product_id;

        INSERT INTO order_items (order_id, product_id, quantity, unit_price)
        VALUES (v_order_id, v_item.product_id, v_item.quantity, v_unit_price);
    END LOOP;

    -- --------------------------------------------------------
    -- STEP 6: Record payment
    -- --------------------------------------------------------
    INSERT INTO payments (order_id, payment_method, payment_status, amount, transaction_ref, paid_at)
    VALUES (v_order_id, p_payment_method::payment_method_enum, 'completed', v_total_amount, p_transaction_ref, NOW());

    -- --------------------------------------------------------
    -- STEP 7: Approve the order (audit trigger fires here)
    -- --------------------------------------------------------
    UPDATE orders
    SET order_status = 'approved'
    WHERE order_id = v_order_id;

    -- --------------------------------------------------------
    -- STEP 8: Create shipment record
    -- --------------------------------------------------------

    SELECT c.state_code INTO v_customer_state
    FROM   customers c WHERE c.customer_id = p_customer_id;

    SELECT s.state_code INTO v_seller_state
    FROM   sellers s WHERE s.seller_id = v_seller_id;

    v_delivery_date := calculate_estimated_delivery_date(v_seller_state, v_customer_state);

    INSERT INTO shipments (order_id, seller_id, estimated_delivery, shipment_status)
    VALUES (v_order_id, v_seller_id, v_delivery_date, 'pending');

    -- --------------------------------------------------------
    -- Return result
    -- --------------------------------------------------------
    RETURN QUERY
    SELECT v_order_id,
           'approved'::VARCHAR(50),
           v_total_amount,
           format('Order #%s placed successfully. Estimated delivery: %s',
                  v_order_id, v_delivery_date)::TEXT;

EXCEPTION
    WHEN OTHERS THEN
        RAISE; -- Re-raise so caller sees the error; transaction auto-rolls back
END;
$$;

\echo '  [OK] process_order_checkout() created.'