-- =============================================================
-- 01_create_tables.sql
-- Full relational schema in 3NF / BCNF
-- Includes all PKs, FKs, CHECK constraints, NOT NULL
-- =============================================================

-- Drop existing tables in reverse dependency order
DROP TABLE IF EXISTS order_status_audit CASCADE;
DROP TABLE IF EXISTS inventory_audit     CASCADE;
DROP TABLE IF EXISTS payments            CASCADE;
DROP TABLE IF EXISTS shipments           CASCADE;
DROP TABLE IF EXISTS order_items         CASCADE;
DROP TABLE IF EXISTS orders              CASCADE;
DROP TABLE IF EXISTS inventory           CASCADE;
DROP TABLE IF EXISTS products            CASCADE;
DROP TABLE IF EXISTS categories          CASCADE;
DROP TABLE IF EXISTS sellers             CASCADE;
DROP TABLE IF EXISTS customers           CASCADE;
DROP TABLE IF EXISTS states              CASCADE;

-- -----------------------------------------------------------
-- ENUM TYPES
-- -----------------------------------------------------------
DO $$ BEGIN
    CREATE TYPE order_status_enum   AS ENUM ('created','approved','shipped','delivered','cancelled');
    CREATE TYPE payment_status_enum AS ENUM ('pending','completed','failed','refunded');
    CREATE TYPE payment_method_enum AS ENUM ('credit_card','debit_card','upi','net_banking','wallet');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- -----------------------------------------------------------
-- STATES (lookup table for delivery estimation)
-- -----------------------------------------------------------
CREATE TABLE states (
    state_code   CHAR(2)      PRIMARY KEY,
    state_name   VARCHAR(100) NOT NULL UNIQUE,
    region       VARCHAR(50)  NOT NULL  -- e.g. 'North', 'South', 'East', 'West'
);

-- -----------------------------------------------------------
-- CUSTOMERS
-- -----------------------------------------------------------
CREATE TABLE customers (
    customer_id   SERIAL       PRIMARY KEY,
    first_name    VARCHAR(100) NOT NULL,
    last_name     VARCHAR(100) NOT NULL,
    email         VARCHAR(255) NOT NULL UNIQUE,
    phone         VARCHAR(15)  NOT NULL UNIQUE,
    address_line  TEXT         NOT NULL,
    city          VARCHAR(100) NOT NULL,
    state_code    CHAR(2)      NOT NULL REFERENCES states(state_code),
    pincode       CHAR(6)      NOT NULL CHECK (pincode ~ '^\d{6}$'),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE
);

-- -----------------------------------------------------------
-- SELLERS
-- -----------------------------------------------------------
CREATE TABLE sellers (
    seller_id     SERIAL       PRIMARY KEY,
    business_name VARCHAR(200) NOT NULL,
    contact_email VARCHAR(255) NOT NULL UNIQUE,
    contact_phone VARCHAR(15)  NOT NULL UNIQUE,
    address_line  TEXT         NOT NULL,
    city          VARCHAR(100) NOT NULL,
    state_code    CHAR(2)      NOT NULL REFERENCES states(state_code),
    pincode       CHAR(6)      NOT NULL CHECK (pincode ~ '^\d{6}$'),
    rating        NUMERIC(2,1)          CHECK (rating BETWEEN 0 AND 5),
    is_active     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------
-- CATEGORIES
-- -----------------------------------------------------------
CREATE TABLE categories (
    category_id   SERIAL       PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    parent_id     INT                   REFERENCES categories(category_id)
);

-- -----------------------------------------------------------
-- PRODUCTS
-- -----------------------------------------------------------
CREATE TABLE products (
    product_id    SERIAL         PRIMARY KEY,
    seller_id     INT            NOT NULL REFERENCES sellers(seller_id),
    category_id   INT            NOT NULL REFERENCES categories(category_id),
    product_name  VARCHAR(300)   NOT NULL,
    description   TEXT,
    unit_price    NUMERIC(12,2)  NOT NULL CHECK (unit_price >= 0),
    weight_kg     NUMERIC(8,3)            CHECK (weight_kg > 0),
    is_active     BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------
-- INVENTORY  (one row per product per warehouse location)
-- -----------------------------------------------------------
CREATE TABLE inventory (
    inventory_id     SERIAL      PRIMARY KEY,
    product_id       INT         NOT NULL REFERENCES products(product_id),
    warehouse_state  CHAR(2)     NOT NULL REFERENCES states(state_code),
    stock_quantity   INT         NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
    reorder_level    INT         NOT NULL DEFAULT 10,
    last_updated     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (product_id, warehouse_state)
);

-- -----------------------------------------------------------
-- ORDERS
-- -----------------------------------------------------------
CREATE TABLE orders (
    order_id        SERIAL             PRIMARY KEY,
    customer_id     INT                NOT NULL REFERENCES customers(customer_id),
    seller_id       INT                NOT NULL REFERENCES sellers(seller_id),
    order_status    order_status_enum  NOT NULL DEFAULT 'created',
    total_amount    NUMERIC(14,2)      NOT NULL CHECK (total_amount >= 0),
    shipping_addr   TEXT               NOT NULL,
    placed_at       TIMESTAMPTZ        NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ        NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------
-- ORDER ITEMS
-- -----------------------------------------------------------
CREATE TABLE order_items (
    order_item_id   SERIAL         PRIMARY KEY,
    order_id        INT            NOT NULL REFERENCES orders(order_id),
    product_id      INT            NOT NULL REFERENCES products(product_id),
    quantity        INT            NOT NULL CHECK (quantity > 0),
    unit_price      NUMERIC(12,2)  NOT NULL CHECK (unit_price >= 0),
    subtotal        NUMERIC(14,2)  GENERATED ALWAYS AS (quantity * unit_price) STORED,
    UNIQUE (order_id, product_id)
);

-- -----------------------------------------------------------
-- PAYMENTS
-- -----------------------------------------------------------
CREATE TABLE payments (
    payment_id      SERIAL              PRIMARY KEY,
    order_id        INT                 NOT NULL UNIQUE REFERENCES orders(order_id),
    payment_method  payment_method_enum NOT NULL,
    payment_status  payment_status_enum NOT NULL DEFAULT 'pending',
    amount          NUMERIC(14,2)       NOT NULL CHECK (amount >= 0),
    transaction_ref VARCHAR(100)        UNIQUE,
    paid_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------
-- SHIPMENTS
-- -----------------------------------------------------------
CREATE TABLE shipments (
    shipment_id       SERIAL      PRIMARY KEY,
    order_id          INT         NOT NULL UNIQUE REFERENCES orders(order_id),
    seller_id         INT         NOT NULL REFERENCES sellers(seller_id),
    tracking_number   VARCHAR(100)         UNIQUE,
    courier_name      VARCHAR(100),
    shipment_status   VARCHAR(50) NOT NULL DEFAULT 'pending',
    shipped_at        TIMESTAMPTZ,
    estimated_delivery DATE,
    delivered_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -----------------------------------------------------------
-- ORDER STATUS AUDIT (immutable log)
-- -----------------------------------------------------------
CREATE TABLE order_status_audit (
    audit_id        SERIAL            PRIMARY KEY,
    order_id        INT               NOT NULL REFERENCES orders(order_id),
    old_status      order_status_enum,
    new_status      order_status_enum NOT NULL,
    changed_at      TIMESTAMPTZ       NOT NULL DEFAULT NOW(),
    changed_by_user VARCHAR(100)      NOT NULL DEFAULT current_user
);

-- -----------------------------------------------------------
-- INVENTORY AUDIT (immutable log)
-- -----------------------------------------------------------
CREATE TABLE inventory_audit (
    audit_id          SERIAL      PRIMARY KEY,
    inventory_id      INT         NOT NULL REFERENCES inventory(inventory_id),
    product_id        INT         NOT NULL REFERENCES products(product_id),
    order_id          INT                  REFERENCES orders(order_id),
    quantity_before   INT         NOT NULL,
    quantity_deducted INT         NOT NULL,
    quantity_after    INT         NOT NULL,
    action            VARCHAR(50) NOT NULL,
    changed_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    changed_by_user   VARCHAR(100)NOT NULL DEFAULT current_user
);

\echo '--> Schema tables created successfully.'