# Project Defense & Technical Guide: E-Commerce OLTP Engine

**Project Title:** Design and Implementation of a High-Concurrency E-Commerce OLTP Engine with Strict ACID Guarantees  
**Domain:** Database Management Systems (DBMS), Advanced Relational Design, Concurrency Control, Full-Stack Architecture  

---

## 1. Executive Summary & Objective

In modern e-commerce systems, race conditions, partial checkouts, inventory inconsistency (overselling), and lack of non-repudiation (audit tracking) lead to critical operational and financial failures. 

This project implements a complete, enterprise-grade **Online Transaction Processing (OLTP) Engine** powered by **PostgreSQL**, exposed via an asynchronous **FastAPI** backend, and consumed by a **React** user interface.

### Core Database Systems Principles Demonstrated:
1. **Relational Normalization (3NF / BCNF)** with declarative integrity constraints.
2. **ACID Transactions** orchestrating multi-table pipelines.
3. **Pessimistic Concurrency Control** via `SELECT ... FOR UPDATE` row-level locks preventing the classic *Lost Update* and *Overselling* anomalies.
4. **Transaction Isolation Levels** evaluated under high concurrency (`REPEATABLE READ` and `SERIALIZABLE`).
5. **Event-Driven Database Triggers** executing business logic automatically (warehouse allocation, immutable audit journaling).
6. **Procedural Stored Procedures (`PL/pgSQL`)** keeping transaction logic internal to the database to minimize network latency roundtrips.

---

## 2. Relational Database Architecture

The schema consists of **12 relational tables** organized into five operational subsystems:

```
[states] ──< [customers] ──< [orders] >── [sellers] >── [states]
                               │    │         │
                               │    ├──< [shipments]
                               │    └──< [payments]
                               │
                          [order_items] >── [products] >── [categories]
                                                  │
                                             [inventory] >── [states]
                                                  │
                      ┌───────────────────────────┴───────────────────────────┐
                      ▼                                                       ▼
            [inventory_audit] (append-only)                       [order_status_audit] (append-only)
```

### Table Breakdown & Design Rationale:
1. **`states`**: Lookup table (`state_code CHAR(2) PK`, `region`). Used for cross-regional logistics and delivery calculation.
2. **`customers`**: Stores buyer identities, hashed credentials, address details, and contact numbers with strict regex validation (`CHECK (pincode ~ '^\d{6}$')`).
3. **`sellers`**: Multi-vendor sellers with ratings (`CHECK (rating BETWEEN 0 AND 5)`) and geographical presence.
4. **`categories`**: Adjacency list self-referential hierarchy (`parent_id REFERENCES categories(category_id)`).
5. **`products`**: Inventory master entity linked to sellers and categories. Enforces price non-negativity (`CHECK (unit_price >= 0)`).
6. **`inventory`**: Multi-warehouse distribution (`product_id`, `warehouse_state`, `stock_quantity`, `reorder_level`).
   - Natural Composite Unique Key: `UNIQUE (product_id, warehouse_state)`.
   - Domain Constraint: `CHECK (stock_quantity >= 0)` ensures physical stock can never become negative at the storage layer.
7. **`orders`**: Master order headers tracking status via enum (`created`, `approved`, `shipped`, `delivered`, `cancelled`).
8. **`order_items`**: Line items for orders. Contains a computed column:  
   `subtotal NUMERIC(14,2) GENERATED ALWAYS AS (quantity * unit_price) STORED`.
9. **`payments`**: 1-to-1 relationship with orders (`order_id UNIQUE`). Tracks payment states (`pending`, `completed`, `failed`, `refunded`) and transaction identifiers.
10. **`shipments`**: 1-to-1 fulfillment tracking, calculated estimated delivery dates, and couriers.
11. **`order_status_audit`**: Immutable event ledger capturing `(old_status -> new_status)` transitions, timestamp, and database user.
12. **`inventory_audit`**: Immutable ledger recording inventory balance changes (`quantity_before`, `quantity_deducted`, `quantity_after`, `action`).

---

## 3. Concurrency Control, Locking & ACID Guarantees

### 3.1 The Oversell Problem (Write-Skew / Lost Update)
If two concurrent checkout requests read that a product has 1 unit of stock simultaneously, both evaluate `stock >= 1` as true, and both issue an `UPDATE inventory SET stock_quantity = stock_quantity - 1`. The stock becomes `0` or negative, and two customers are billed for one unit.

### 3.2 Mitigation: Row-Level Locking (`FOR UPDATE`)
Inside the warehouse allocation trigger (`fn_deduct_inventory`):
```sql
SELECT inv.inventory_id, inv.stock_quantity
  INTO v_inventory_id, v_stock_before
  FROM inventory inv
 WHERE inv.product_id = NEW.product_id
   AND inv.stock_quantity >= NEW.quantity
 ORDER BY (inv.warehouse_state = v_seller_state) DESC,
          inv.stock_quantity DESC
 LIMIT 1
   FOR UPDATE;  -- <--- PESSIMISTIC EXCLUSIVE LOCK
```
* **How it works:** The database acquires an exclusive row lock on the selected inventory row. Any concurrent transaction attempting to read or update that same inventory row is forced into a queue until the first transaction commits or aborts.
* **Deadlock Prevention:** Queries access products and inventory in a deterministic sorted order, preventing cross-dependency lock cycles.

### 3.3 Transaction Isolation Levels
* **`READ COMMITTED` (Default):** Guarantees statements see only committed data, but subject to non-repeatable reads and phantom reads within the same transaction.
* **`REPEATABLE READ`:** Used during our checkout verification to ensure an order item list read remains snapshot-consistent during calculations.
* **`SERIALIZABLE`:** The highest isolation level in ANSI SQL. Uses Serializable Snapshot Isolation (SSI) to detect read/write conflicts and dependency cycles, aborting conflicting transactions with serialization failures so the client can safely retry.

---

## 4. Stored Procedures & Triggers (`PL/pgSQL`)

### 4.1 Stored Procedure: `process_order_checkout()`
Orchestrates the entire checkout workflow in a single atomic transaction:
1. **Validates Customer:** Verifies customer exists, is active, and retrieves formatted address.
2. **Validates Cart:** Checks item counts, ensures non-zero positive quantities, and confirms total inventory availability.
3. **Creates Order Record:** Inserts into `orders` with status `'created'`.
4. **Inserts Order Items:** Inserts lines into `order_items`. This immediately activates downstream triggers.
5. **Records Payment:** Inserts into `payments` with method type-cast (`p_payment_method::payment_method_enum`).
6. **Transitions Status:** Updates order to `'approved'`.
7. **Calculates Delivery & Dispatches:** Calls `calculate_estimated_delivery_date()` and inserts into `shipments`.

### 4.2 Trigger 1: `trg_deduct_inventory` (Event-driven allocation)
* **Trigger Event:** `AFTER INSERT ON order_items FOR EACH ROW`
* **Action:**
  - Attempts to locate a warehouse located in the seller's state first (proximity fulfillment).
  - Falls back to any warehouse containing sufficient stock.
  - Decrements the quantity.
  - Writes an entry to `inventory_audit` documenting `quantity_before`, `quantity_deducted`, and `quantity_after`.

### 4.3 Trigger 2: `trg_audit_order_status` (Auditability)
* **Trigger Event:** `BEFORE UPDATE OF order_status ON orders FOR EACH ROW`
* **Action:**
  - Evaluates `IF NEW.order_status IS DISTINCT FROM OLD.order_status`.
  - Inserts the state change into `order_status_audit`.
  - Automatically updates `NEW.updated_at := NOW()`.

### 4.4 Stored Procedure: `process_order_cancellation()`
Handles reverse logistics:
* Locks the order row (`FOR UPDATE`).
* Rejects cancellation if already `shipped`, `delivered`, or `cancelled`.
* Loops through order items, adds stock back to `inventory`, and creates negative deduction entries in `inventory_audit` (`action = 'replenishment'`).
* Sets payment status to `'refunded'` and order status to `'cancelled'`.

---

## 5. Backend Architecture (FastAPI & asyncpg)

The backend acts as an asynchronous interface between the REST client and the PostgreSQL database.

* **Driver:** `asyncpg` (Direct asynchronous PostgreSQL wire protocol connection pool; eliminates ORM overhead and runs native SQL/PLpgSQL).
* **Connection Pooling:** `get_db_pool()` maintains reusable database connections, avoiding the expensive overhead of TCP handshakes per request.
* **Authentication Subsystem (`auth.py`):**
  - Uses direct `bcrypt` hashing (`bcrypt.checkpw`, `bcrypt.gensalt`) avoiding outdated wrapper layers.
  - Issues signed JSON Web Tokens (JWT) using `python-jose` containing identity and role (`customer` vs `seller`).
* **Endpoints (`main.py`):**
  - `POST /auth/customer/login` & `POST /auth/seller/login`: Validates password hash against DB records and issues JWT.
  - `GET /products`: Performs aggregated join across products, categories, sellers, and inventory with `HAVING SUM(stock_quantity) > 0`.
  - `POST /customer/{customer_id}/checkout`: Groups multi-seller cart items, formats PostgreSQL composite arrays (`ARRAY[...]::cart_item[]`), and executes `process_order_checkout()`.
  - `POST /seller/{seller_id}/products`: Transactionally inserts new products and creates initial inventory.

---

## 6. Teacher Viva / Presentation Cheat Sheet

### Top 10 Technical Questions & Winning Answers

#### Q1: "Why did you implement business logic inside Stored Procedures and Triggers rather than in Python/Node?"
> **Answer:** *"Placing transaction logic inside PostgreSQL stored procedures minimizes network roundtrips between the app server and database. Instead of making 6 back-and-forth network requests (read stock, check price, insert order, insert items, update inventory, insert audit), we send one procedure call. Crucially, it guarantees atomicity directly at the database tier; even if an external script connects or the backend server crashes halfway through, the database cannot be left in an inconsistent state."*

#### Q2: "What normal form is your schema in?"
> **Answer:** *"The schema is in Third Normal Form (3NF) and Boyce-Codd Normal Form (BCNF). All attributes are atomic (1NF), all non-key attributes are fully functionally dependent on the primary keys without partial dependencies (2NF), and there are no transitive dependencies (3NF). Address components and pricing are isolated, and order item subtotals are generated columns rather than manually maintained redundant fields."*

#### Q3: "How does your database handle two users buying the last item at the exact same millisecond?"
> **Answer:** *"We use pessimistic concurrency control with `SELECT ... FOR UPDATE` inside the inventory deduction trigger. When the first transaction reaches that row, PostgreSQL places an exclusive lock on it. The second transaction must wait. Once transaction 1 deducts the stock to 0 and commits, transaction 2 reads the updated balance (0), fails the availability check, and raises an exception that cleanly aborts with an 'Insufficient Stock' error."*

#### Q4: "What is the difference between REPEATABLE READ and SERIALIZABLE?"
> **Answer:** *"REPEATABLE READ guarantees that any data read during a transaction will not change for the duration of that transaction snapshot, preventing dirty reads and non-repeatable reads. However, it can still experience write-skew or phantom inserts in edge cases. SERIALIZABLE completely prevents all concurrency anomalies by monitoring read/write locks (SSI). If PostgreSQL detects a serialization conflict where concurrent transactions cannot be ordered sequentially, it aborts one with error 40001 so the application can retry."*

#### Q5: "Why did you create an audit table instead of just keeping an `updated_at` column?"
> **Answer:** *"An `updated_at` column only tells you when the latest update happened, overwriting history. An audit ledger (`order_status_audit` and `inventory_audit`) is an append-only historical log. It preserves non-repudiation: we can reconstruct every state transition, the user responsible, and precise timestamps, which is mandatory for compliance, dispute resolution, and fraud prevention."*

#### Q6: "Why do you have indexes on Foreign Keys? Doesn't PostgreSQL create them automatically?"
> **Answer:** *"No, PostgreSQL automatically creates unique indexes for Primary Keys and UNIQUE constraints, but **not** for Foreign Keys. We explicitly indexed all foreign keys (`order_id`, `customer_id`, `product_id`) because relational JOIN queries and cascading operations look up parent-child relationships frequently. Without these indexes, joining `orders` and `order_items` would degrade to slow Full Table Scans."*

#### Q7: "What is a Composite Type in PostgreSQL, and why did you use one?"
> **Answer:** *"We defined `CREATE TYPE cart_item AS (product_id INT, quantity INT)`. This allows the application to pass an entire shopping cart (an array of tuples) into a single stored procedure argument `p_cart_items cart_item[]`. It eliminates the need for temporary tables or comma-delimited string parsing inside SQL."*

#### Q8: "How is your Python backend communicating with PostgreSQL?"
> **Answer:** *"We use `asyncpg`, which is an asynchronous driver implemented on the PostgreSQL binary protocol. It manages a connection pool (`get_db_pool()`). Connections are reused across requests, and because it is fully non-blocking, the backend can handle thousands of concurrent queries on a single event loop without blocking CPU threads."*

#### Q9: "What happens if the payment step fails during checkout?"
> **Answer:** *"The stored procedure operates under ACID transaction boundaries. If payment recording fails or an exception is thrown anywhere before the transaction block commits, PostgreSQL executes a complete automatic `ROLLBACK`. The order row, order items, and inventory deductions are reverted as if they never happened."*

#### Q10: "Can an auditor delete records from your audit log?"
> **Answer:** *"By default, table privileges dictate deletions. In our test suite, we verified that deleting an audit log leaves an orphan warning. For production readiness, we can apply PostgreSQL Row Level Security (RLS) or an explicit `CREATE RULE ... AS ON DELETE DO INSTEAD NOTHING` to make the audit tables physically immutable even to privileged application users."*

---

## 7. Step-by-Step Live Demonstration Script

When presenting to your teacher, execute these steps in order:

1. **Show the Schema & Entity Relationship:**
   - Open **pgAdmin 4** or your SQL files.
   - Point out constraints: `CHECK` constraints on stock (`>= 0`), foreign keys, and ENUM types (`order_status_enum`).
2. **Execute Automated Verification Suite:**
   - Run in PowerShell:
     ```powershell
     & "C:\Program Files\PostgreSQL\18\bin\psql.exe" -U postgres -d ecommerce_db -f run_all.sql
     ```
   - Show the teacher the clean `[OK]` output for all sections: Schema -> Triggers -> Stored Procedures -> Concurrency Tests -> Happy Path -> Oversell Tests -> Cancellation -> Audit Log.
3. **Highlight the Concurrency Test (`concurrency_test.sql`):**
   - Point out **TEST 1 (Oversell Prevention)** where Session A takes the last unit, and Session B is cleanly rejected without corrupting data.
4. **Show Live Audit Trail:**
   - Query `order_status_audit` and `inventory_audit` in pgAdmin to show how placing and cancelling an order automatically generates an audit trail without writing a single audit line in backend code.
5. **Show Live App Execution:**
   - Log in with `arjun.sharma@email.com` / `password123`.
   - Place an order from the UI.
   - Show the teacher the new record in PostgreSQL directly!
