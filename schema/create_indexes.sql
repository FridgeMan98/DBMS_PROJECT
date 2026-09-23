-- =============================================================
-- 02_create_indexes.sql
-- Indexes on all FK columns + frequently queried fields
-- =============================================================

-- CUSTOMERS
CREATE INDEX idx_customers_state        ON customers(state_code);
CREATE INDEX idx_customers_email        ON customers(email);

-- SELLERS
CREATE INDEX idx_sellers_state          ON sellers(state_code);

-- PRODUCTS
CREATE INDEX idx_products_seller        ON products(seller_id);
CREATE INDEX idx_products_category      ON products(category_id);
CREATE INDEX idx_products_active        ON products(is_active);

-- INVENTORY
CREATE INDEX idx_inventory_product      ON inventory(product_id);
CREATE INDEX idx_inventory_warehouse    ON inventory(warehouse_state);
CREATE INDEX idx_inventory_low_stock    ON inventory(stock_quantity) WHERE stock_quantity <= reorder_level;

-- ORDERS
CREATE INDEX idx_orders_customer        ON orders(customer_id);
CREATE INDEX idx_orders_seller          ON orders(seller_id);
CREATE INDEX idx_orders_status          ON orders(order_status);
CREATE INDEX idx_orders_placed_at       ON orders(placed_at DESC);

-- ORDER ITEMS
CREATE INDEX idx_order_items_order      ON order_items(order_id);
CREATE INDEX idx_order_items_product    ON order_items(product_id);

-- PAYMENTS
CREATE INDEX idx_payments_order         ON payments(order_id);
CREATE INDEX idx_payments_status        ON payments(payment_status);

-- SHIPMENTS
CREATE INDEX idx_shipments_order        ON shipments(order_id);

-- AUDIT TABLES
CREATE INDEX idx_status_audit_order     ON order_status_audit(order_id);
CREATE INDEX idx_status_audit_changed   ON order_status_audit(changed_at DESC);
CREATE INDEX idx_inventory_audit_order  ON inventory_audit(order_id);
CREATE INDEX idx_inventory_audit_prod   ON inventory_audit(product_id);

\echo '--> Indexes created successfully.'