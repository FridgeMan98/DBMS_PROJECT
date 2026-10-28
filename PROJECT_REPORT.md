# BCSE497J - Project-I / DATABASE SYSTEM Assessment - 7

# END-TO-END E-COMMERCE PLATFORM: INTEGRATING A REACT/FASTAPI STACK WITH AN ADVANCED POSTGRESQL OLTP BACKEND

| Reg. No. | Student Name |
| :--- | :--- |
| **25BCE0136** | **ARYA ARAVINDAN** |
| **25BDS0248** | **ARYAN RANGARAJAN** |

<br>

**Under the Supervision of**  
**Dr. [Project Guide Name]**  
[Designation]  
School of Computer Science and Engineering (SCOPE)  

<br>

**B.Tech.**  
**in**  
**Computer Science and Engineering**  
School of Computer Science and Engineering  
**Vellore Institute of Technology**  
October 2026  

---

## ABSTRACT

E-commerce platforms require robust data consistency, especially during high-volume concurrent transactions such as checkout and inventory management. This project presents the design and implementation of a full-stack E-Commerce Online Transaction Processing (OLTP) engine. The core system is built on PostgreSQL, utilizing advanced database features including PL/pgSQL stored procedures, dynamic triggers, and strict constraint management to push critical business logic directly to the data layer. 

A primary focus of this project is the mitigation of race conditions—such as inventory overselling and phantom reads—through explicit row-level locking (`SELECT ... FOR UPDATE`) and the implementation of varied transaction isolation levels (Repeatable Read and Serializable). Furthermore, the architecture includes an immutable, trigger-based audit trail to track order state changes and inventory deductions securely. To demonstrate real-world application, the database is integrated with a modern web architecture, featuring a FastAPI Python backend and a React user interface. The resulting system successfully illustrates how strict database-level concurrency control and transaction management can guarantee data integrity in a highly dynamic e-commerce environment.

**Keywords** — Relational Database Management Systems, PostgreSQL, OLTP, Concurrency Control, Row-Level Locking, ACID Properties, Stored Procedures, Database Triggers, FastAPI, React.

---

## TABLE OF CONTENTS

| Sl.No | Contents | Page No. |
| :--- | :--- | :--- |
| | **Abstract** | **i** |
| **1.** | **INTRODUCTION** | **1** |
| | 1.1 Background | 1 |
| | 1.2 Motivations | 1 |
| | 1.3 Scope of the Project | 2 |
| **2.** | **PROJECT DESCRIPTION AND GOALS** | **3** |
| | 2.1 Literature Review | 3 |
| | 2.2 Research Gap | 4 |
| | 2.3 Objectives | 4 |
| | 2.4 Problem Statement | 5 |
| | 2.5 Project Plan | 5 |
| **3.** | **TECHNICAL SPECIFICATION** | **7** |
| | 3.1 Requirements | 7 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.1.1 Functional Requirements | 7 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.1.2 Non-Functional Requirements | 8 |
| | 3.2 Feasibility Study | 8 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.2.1 Technical Feasibility | 8 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.2.2 Economic Feasibility | 9 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.2.3 Social Feasibility | 9 |
| | 3.3 System Specification | 10 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.3.1 Hardware Specification | 10 |
| | &nbsp;&nbsp;&nbsp;&nbsp;3.3.2 Software Specification | 10 |
| **4.** | **DESIGN APPROACH AND DETAILS** | **11** |
| | 4.1 System Architecture | 11 |
| | 4.2 Design | 12 |
| | &nbsp;&nbsp;&nbsp;&nbsp;4.2.1 Data Flow Diagram (DFD Level 0 & Level 1) | 12 |
| | &nbsp;&nbsp;&nbsp;&nbsp;4.2.2 Use Case Diagram | 14 |
| | &nbsp;&nbsp;&nbsp;&nbsp;4.2.3 Class Diagram and Relational Schema | 15 |
| | &nbsp;&nbsp;&nbsp;&nbsp;4.2.4 Sequence Diagram | 17 |
| **5.** | **REFERENCES** | **19** |

---

# 1. INTRODUCTION

### 1.1 Background
The digital commerce economy relies heavily on robust Online Transaction Processing (OLTP) systems capable of handling thousands of concurrent requests per second. At the heart of any commercial platform lies the database management system, which must guarantee data consistency, fault tolerance, and absolute reliability during critical events such as flash sales and multi-item checkouts. Traditional software engineering practices often delegate transactional integrity to application-level code or object-relational mapping (ORM) layers. However, this architectural pattern frequently introduces critical latency, race conditions, and data inconsistency when concurrent transactions interleave unpredictably. Relational databases such as PostgreSQL offer sophisticated native concurrency control mechanisms, declarative constraints, procedural extensions (PL/pgSQL), and event-driven triggers. By anchoring transaction orchestration and business rules within the database engine itself, systems can achieve unparalleled data integrity and performance. This project explores the design, formalization, and deployment of a resilient e-commerce OLTP database architecture seamlessly integrated with a modern asynchronous FastAPI backend and a React client interface.

### 1.2 Motivation
In high-throughput e-commerce ecosystems, concurrent access to mutable resources inevitably triggers concurrency anomalies, most notably the "overselling" problem (a manifestation of the Lost Update and Write-Skew anomalies). When multiple customers concurrently attempt to purchase the last available stock unit of a popular product, standard non-locking read operations can read identical inventory counts, validate availability in parallel, and commit conflicting inventory decrements. This results in negative stock levels, order cancellations, financial loss, and severe brand reputational damage. Furthermore, standard application-level logging frequently fails to maintain strict non-repudiation when errors or unauthorized data mutations occur. These critical industry vulnerabilities motivated this project: to demonstrate that pushing pessimistic row-level locking (`SELECT ... FOR UPDATE`), transaction isolation levels (`REPEATABLE READ` and `SERIALIZABLE`), and automated trigger-based audit ledgers directly into PostgreSQL fundamentally eliminates race conditions, guarantees ACID compliance, and provides an unforgeable compliance trail.

### 1.3 Scope of the Project
The scope of this project encompasses the design, formal relational modeling, implementation, testing, and full-stack integration of an enterprise-grade e-commerce OLTP system. The project scope covers:
1. Formulating a normalized relational schema (Third Normal Form / Boyce-Codd Normal Form) spanning 12 interconnected tables with domain constraints, regex validations, foreign key cascades, and computed generated columns.
2. Authoring atomic PL/pgSQL stored procedures for multi-item order checkout (`process_order_checkout`) and reverse-logistics cancellation (`process_order_cancellation`).
3. Developing automated database triggers for multi-warehouse inventory allocation (`trg_deduct_inventory`) and immutable status tracking (`trg_audit_order_status`).
4. Evaluating transaction isolation levels and validating race condition mitigation through automated concurrency testing suites.
5. Implementing an asynchronous Python/FastAPI gateway utilizing connection pooling (`asyncpg`) and salted bcrypt authentication.
6. Deploying a responsive React/Vite web interface demonstrating consumer purchasing, inventory updates, and seller management.

---

# 2. PROJECT DESCRIPTION AND GOALS

### 2.1 Literature Review
Modern database research emphasizes the criticality of concurrency control and transactional guarantees in data-intensive web applications. The seminal work by Gray et al. [1] established the foundational principles of transaction processing and ACID (Atomicity, Consistency, Isolation, Durability) guarantees, emphasizing that data integrity must be maintained despite system crashes or concurrent thread execution. Berenson et al. [2] critically analyzed the ANSI SQL-92 isolation levels, demonstrating that standard definitions failed to capture several significant concurrency phenomena, including Cursor Stability, Snapshot Isolation, and Write Skew. Their findings underlined the necessity of explicit row-level locking mechanisms (`SELECT ... FOR UPDATE`) to prevent non-repeatable reads and lost updates in commercial workloads.

In high-concurrency environments, multi-version concurrency control (MVCC) has become the de facto standard for modern relational database engines, notably PostgreSQL. As investigated by Momjian [3], PostgreSQL's MVCC architecture allows readers to avoid blocking writers and writers to avoid blocking readers. However, in write-intensive OLTP scenarios where multiple transactions compete to modify the same scalar integer (such as product inventory counts), MVCC alone cannot prevent serialization conflicts without explicit locking protocols or Serializable Snapshot Isolation (SSI), as explored by Ports and Grittner [4].

Furthermore, research into database tier versus application tier logic by Stonebraker and Cattell [5] demonstrated that pushing complex transactional pipelines into procedural database objects (stored procedures and triggers) dramatically reduces network roundtrip overhead and context-switching penalties. In an e-commerce checkout context, executing customer validation, stock deduction, shipment creation, and payment recording in a single atomic database execution minimizes serialization windows, thereby reducing lock contention and preventing deadlocks.

### 2.2 Research Gap
Existing commercial and academic implementations of e-commerce web applications typically delegate business validations and inventory checks to the web application tier or intermediate caching layers (e.g., Redis locks, ORM interceptors). While this abstracts SQL logic from developers, it introduces several critical deficiencies:
1. **Application-Level Latency Windows:** In an application-level checkout sequence, the application executes multiple sequential roundtrips over TCP (read stock -> validate in Python -> send order insert -> send inventory update). This extended latency window dramatically increases the vulnerability duration for race conditions.
2. **Lack of Immutable Non-Repudiation:** Application-level audit logging is vulnerable to silent failures; if the application crashes midway or if direct database updates occur outside the web application, the audit trail is permanently corrupted or omitted.
3. **Improper Handling of Concurrent Write-Skews:** Most basic full-stack applications run under PostgreSQL's default `READ COMMITTED` isolation level without explicit row-level locks, leading to rampant stock overselling when subjected to concurrent load spikes.

This project bridges these gaps by providing an end-to-end engineered architecture where database triggers and PL/pgSQL procedures execute transactional logic internally, utilizing explicit pessimistic row locks and automated audit tables.

### 2.3 Objectives
The primary objectives of this project are:
1. **Design a Normalized 3NF/BCNF Relational Schema:** Establish a 12-table relational schema with strict domain integrity constraints (e.g., non-negative inventory `CHECK (stock_quantity >= 0)`, Indian pincode regex matching, and generated columns).
2. **Implement Atomic Stored Procedures:** Develop PL/pgSQL procedures to encapsulate multi-table checkout and cancellation workflows within single transactional boundaries.
3. **Engineer Event-Driven Automation Triggers:** Implement triggers to execute proximity-based warehouse stock deduction and record immutable chronological entries in audit ledgers (`order_status_audit` and `inventory_audit`).
4. **Prevent Race Conditions and Overselling:** Formulate and verify pessimistic row-level locking (`SELECT ... FOR UPDATE`) capable of handling simultaneous checkout attempts without negative stock occurrences.
5. **Analyze Transaction Isolation Behaviors:** Evaluate and benchmark the system under `REPEATABLE READ` and `SERIALIZABLE` isolation levels to observe serialization anomaly resolution.
6. **Deploy Full-Stack Integration:** Connect the PostgreSQL OLTP engine to an asynchronous FastAPI REST service and a React single-page application for real-time validation.

### 2.4 Problem Statement
Under high-concurrency online retail events (e.g., flash sales), standard e-commerce architectures experience race conditions where multiple checkout transactions read identical stock levels concurrently. This leads to duplicate sales of limited items, data anomalies, broken foreign key states during system interruptions, and inconsistent order lifecycle records. The challenge is to architect a database-centric OLTP solution that prevents inventory overselling, guarantees strict ACID properties, logs immutable audit events, and provides sub-50ms execution times across an asynchronous web stack.

### 2.5 Project Plan
The development lifecycle of this project was executed across eight structured phases over four operational months, as detailed in Table 2.1 and illustrated in the Gantt chart (Figure 1).

**Table 2.1: Project Phase Breakdown**
| Task ID | Task Description | Timeline | Deliverables |
| :--- | :--- | :--- | :--- |
| **Task 1** | Literature Survey & Requirement Gathering | Month 1 (Weeks 1–2) | Requirement specification, research gap analysis |
| **Task 2** | Relational Modeling & Schema Design | Month 1 (Weeks 3–4) | 3NF/BCNF DDL scripts, constraints, indexes |
| **Task 3** | Stored Procedures & Trigger Engineering | Month 2 (Weeks 1–2) | `process_order_checkout`, `fn_deduct_inventory` |
| **Task 4** | Concurrency Testing & Lock Verification | Month 2 (Weeks 3–4) | Race condition tests, isolation benchmarks |
| **Task 5** | Backend Development (FastAPI + asyncpg) | Month 3 (Weeks 1–2) | Async REST APIs, connection pooling, JWT auth |
| **Task 6** | Frontend Development (React + Vite) | Month 3 (Weeks 3–4) | Customer catalog, cart, seller dashboard UI |
| **Task 7** | System Integration & End-to-End Testing | Month 4 (Weeks 1–2) | Integrated testing, bug resolution, audit checks |
| **Task 8** | Documentation, Reporting & Defense Prep | Month 4 (Weeks 3–4) | Comprehensive project report, presentation guide |

```
+---------------------------------------------------------------------------------------------------------+
|                                              PROJECT GANTT CHART                                        |
+---------------------------------------------------------------------------------------------------------+
| Phase / Task                        | Month 1 (Dec)     | Month 2 (Jan)     | Month 3 (Feb)     | Month 4 (Mar) |
+-------------------------------------+-------------------+-------------------+-------------------+---------------+
| Task 1: Literature Survey           | [====]            |                   |                   |               |
| Task 2: Relational Schema (3NF)     |      [====]       |                   |                   |               |
| Task 3: Stored Procedures & Triggers|                   | [====]            |                   |               |
| Task 4: Concurrency & Lock Testing  |                   |      [====]       |                   |               |
| Task 5: Backend API (FastAPI)       |                   |                   | [====]            |               |
| Task 6: Frontend UI (React + Vite)  |                   |                   |      [====]       |               |
| Task 7: Full System Integration     |                   |                   |                   | [====]        |
| Task 8: Documentation & Submission  |                   |                   |                   |      [====]   |
+---------------------------------------------------------------------------------------------------------+
```
*Fig. 1. Gantt Chart of Project Execution Plan*

---

# 3. TECHNICAL SPECIFICATION

### 3.1 Requirements

#### 3.1.1 Functional Requirements
1. **User Authentication & Role Management:** The system must securely authenticate Customers and Sellers using salted bcrypt password hashes and issue role-encoded JSON Web Tokens (JWT).
2. **Product Catalog & Dynamic Categorization:** The system must support self-referential hierarchical categories (parent-child relationships) and filter active products with available inventory across regional warehouses.
3. **Multi-Warehouse Stock Management:** The system must track inventory quantities independently across different regional warehouse states (`warehouse_state CHAR(2)`) with automated low-stock reorder thresholds.
4. **Atomic Order Checkout:** The system must execute end-to-end checkout through a single procedure call (`process_order_checkout`), validating customer status, computing order item subtotals, locking stock, inserting order items, recording payments, and generating shipments atomically.
5. **Automated Inventory Deduction & Allocation:** Upon order item insertion, the system must trigger an automated procedure that prioritizes the seller’s local warehouse before falling back to regional warehouses, safely decrementing stock.
6. **Order Cancellation & Reverse Logistics:** The system must support order cancellation for unshipped orders (`process_order_cancellation`), restoring inventory quantities and adjusting payment status to refunded.
7. **Immutable Audit Logging:** The system must record every order status change in `order_status_audit` and every inventory fluctuation in `inventory_audit` with system timestamps and database user identifiers.

#### 3.1.2 Non-Functional Requirements
1. **Performance & Latency:** The database engine must execute multi-item checkout transactions in under 50 milliseconds by utilizing connection pooling (`asyncpg`) and compiled PL/pgSQL execution plans.
2. **Strict Concurrency & Data Consistency:** The database must enforce zero overselling. Even under high-concurrency race conditions, `stock_quantity` must never drop below zero.
3. **Scalability:** The architecture must handle horizontal increases in read traffic via optimized composite B-tree indexing across all foreign key relationships.
4. **Security & Injection Immunity:** The API backend must completely eliminate SQL injection vulnerabilities by enforcing parameterized queries and typed PostgreSQL composite types.
5. **Reliability & ACID Compliance:** All transactions must adhere to strict Atomicity, Consistency, Isolation, and Durability guarantees. Partial checkout failures must automatically trigger a complete transaction rollback.
6. **Maintainability:** Relational tables must conform to 3NF/BCNF, avoiding redundant update overheads through generated stored columns.

### 3.2 Feasibility Study

#### 3.2.1 Technical Feasibility
The project utilizes established, industry-standard technologies with comprehensive documentation and active community support. PostgreSQL 18 is widely recognized for its robust implementation of the ANSI SQL standards, extensible procedural languages (PL/pgSQL), and advanced MVCC concurrency architecture. Python 3.12/3.13 with FastAPI provides an asynchronous event-loop architecture capable of handling concurrent HTTP requests with minimal overhead. The asynchronous driver `asyncpg` communicates directly via PostgreSQL's native binary wire protocol, achieving up to 3x higher throughput compared to traditional synchronous ORMs. On the presentation layer, React 18 with Vite provides a component-driven, state-managed user interface. The technical stack is fully compatible, stable, and completely feasible for high-performance deployment.

#### 3.2.2 Economic Feasibility
The economic feasibility of this project is exceptionally high. The entire software ecosystem—including PostgreSQL, Python, FastAPI, Node.js, and React—is distributed under open-source licenses (PostgreSQL License, MIT, and BSD), incurring zero licensing or acquisition fees. Development and testing were executed on standard commodity computer hardware without the necessity of expensive enterprise servers or specialized cloud accelerators. In commercial production, the computational efficiency achieved by utilizing native stored procedures significantly reduces cloud server memory and CPU footprints, yielding substantial operational cost savings.

#### 3.2.3 Social Feasibility
From a social and operational standpoint, the system delivers high utility to consumers, vendors, and regulatory auditors:
- **Consumer Trust:** By physically eliminating inventory overselling and false order confirmations, customer satisfaction and platform trust are significantly enhanced.
- **Vendor Empowerment:** Multi-vendor support provides localized warehouse stock allocation, optimizing shipping logistics and delivery timelines.
- **Compliance & Transparency:** The immutable, automated audit logging mechanism aligns with regulatory compliance frameworks (e.g., consumer protection laws, financial transaction traceability), ensuring non-repudiation and transparent forensic dispute resolution.

### 3.3 System Specification

#### 3.3.1 Hardware Specification
- **Processor:** Intel Core i5 / AMD Ryzen 5 processor (Quad-core, 2.5 GHz or higher).
- **Primary Memory (RAM):** 8 GB DDR4 minimum (16 GB recommended for concurrent simulation).
- **Secondary Storage:** 256 GB Solid State Drive (SSD) with NVMe interface for high I/O operations per second (IOPS).
- **Display Monitor:** 1080p Full HD monitor (1920 x 1080 resolution).
- **Network Interface:** 1 Gbps Ethernet or Wi-Fi 6 wireless adapter.

#### 3.3.2 Software Specification
- **Operating System:** Microsoft Windows 11 64-bit / Linux Ubuntu 22.04 LTS.
- **Database Server:** PostgreSQL 18.0 Relational Database Management System.
- **Database Tools:** `psql` command-line utility, pgAdmin 4 graphical management console.
- **Backend Language & Runtime:** Python 3.12 / 3.13.
- **Backend Frameworks & Libraries:** FastAPI, Uvicorn (ASGI server), `asyncpg` (async PostgreSQL driver), `bcrypt` (cryptographic password hashing), `python-jose` (JWT handling), Pydantic.
- **Frontend Environment & Framework:** Node.js v20+, React 18, Vite build tool, TypeScript, Axios HTTP client, Lucide React icons.
- **Development Environment (IDE):** Visual Studio Code with SQL, Python, and TypeScript toolchains.

---

# 4. DESIGN APPROACH AND DETAILS

### 4.1 System Architecture
The platform is structured according to a modern 3-Tier Enterprise Architecture, cleanly separating presentation, business application routing, and the data engine, as depicted in Figure 2.

```
+-------------------------------------------------------------------------------+
|                             PRESENTATION TIER                                 |
|                       React 18 + Vite (TypeScript)                            |
|             [Login / Auth]   [Product Catalog]   [Shopping Cart]              |
+---------------------------------------+---------------------------------------+
                                        |  HTTP REST / JSON (Axios)
                                        v
+-------------------------------------------------------------------------------+
|                             APPLICATION TIER                                  |
|                            FastAPI (Python)                                   |
|       [JWT Auth Router]   [Catalog Handler]   [Checkout Dispatcher]           |
|                                       |                                       |
|                  Connection Pool (asyncpg Binary Driver)                      |
+---------------------------------------+---------------------------------------+
                                        |  PostgreSQL Wire Protocol
                                        v
+-------------------------------------------------------------------------------+
|                               DATABASE TIER                                   |
|                        PostgreSQL 18 OLTP Engine                              |
|                                                                               |
|   +-----------------------------------------------------------------------+   |
|   |                       Procedural Logic Layer                          |   |
|   |    process_order_checkout()         process_order_cancellation()      |   |
|   +-----------------------------------+-----------------------------------+   |
|                                       |                                       |
|   +-----------------------------------v-----------------------------------+   |
|   |                       Event-Driven Trigger Layer                      |   |
|   |   trg_deduct_inventory (Row Lock)       trg_audit_order_status        |   |
|   +-----------------------------------+-----------------------------------+   |
|                                       |                                       |
|   +-----------------------------------v-----------------------------------+   |
|   |                       Relational Storage (3NF)                        |   |
|   |   [customers]  [sellers]  [products]  [inventory]  [orders]  [items]  |   |
|   |   [payments]   [shipments]   [order_audit]   [inventory_audit]        |   |
|   +-----------------------------------------------------------------------+   |
+-------------------------------------------------------------------------------+
```
*Fig. 2. Three-Tier System Architecture Diagram*

**Architecture Explanation:**
1. **Presentation Tier:** The user interface provides interactive components for customer registration, seller management, item catalog browsing, dynamic cart accumulation, and checkout submission. Communication with the backend occurs asynchronously via Axios HTTP client utilizing JWT bearer authorization tokens.
2. **Application Tier:** Powered by FastAPI, the application tier serves as a lightweight, non-blocking gateway. It handles request parameter validation via Pydantic models, verifies cryptographic tokens, and borrows connections from an `asyncpg` connection pool. Instead of executing multiple fragmented SQL statements, the application formats parameters into PostgreSQL composite types (`cart_item[]`) and delegates transactional control to stored procedures.
3. **Database Tier:** The core PostgreSQL engine encapsulates the procedural logic, concurrency locking, and relational data tables. Business rules are executed natively, ensuring ACID compliance and eliminating application-to-database network roundtrip latency.

### 4.2 Design

#### 4.2.1 Data Flow Diagram (DFD)

##### DFD Level 0 (Context Diagram)
The Level 0 Context Diagram depicts the primary external entities (Customer, Seller) interacting with the E-Commerce OLTP System boundary.

```
                 +-------------------+
                 |     Customer      |
                 +---------+---------+
                           |
             Credentials,  |   Catalog Data,
             Cart Items,   |   Order Confirmation,
             Payment Info  |   Shipment Status
                           v
              +------------+------------+
              |                         |
              |     E-COMMERCE OLTP     |
              |         SYSTEM          |
              |   (PostgreSQL Core)     |
              |                         |
              +------------+------------+
                           ^
             Seller Info,  |   Fulfillment Reports,
             Product Data, |   Inventory Alerts,
             Restock Info  |   Order Notifications
                           |
                 +---------+---------+
                 |      Seller       |
                 +-------------------+
```
*Fig. 3. Data Flow Diagram - Level 0 (Context Level)*

##### DFD Level 1 (Functional Decomposition)
The Level 1 DFD decomposes the system into four major processes and five primary data stores.

```
 [Customer] ------(Credentials)-----> [ 1.0 Authentication ] <====== (D1: Customers/Sellers)
                                                |
                                          (Auth Token)
                                                v
 [Customer] ----(View Request)------> [ 2.0 Browse Catalog ] <====== (D2: Products/Categories/Inv)
                                                |
                                         (Product List)
                                                v
 [Customer] -----(Cart Items)-------> [ 3.0 Atomic Checkout ] ======> (D3: Orders / Order Items)
                                         |         |
                          (Row-Lock Lock)|         +---------> (D4: Payments)
                                         v                     (D5: Shipments)
                                 [ 4.0 Deduct Stock ]
                                         |
                                         +-------------------> (D2: Inventory Master)
                                         +-------------------> (D6: Audit Ledgers)
```
*Fig. 4. Data Flow Diagram - Level 1 (Functional View)*

#### 4.2.2 Use Case Diagram
The Use Case diagram in Figure 5 models the functional interactions available to Customers and Sellers, alongside automated Database Triggers.

```
  +-----------------------------------------------------------------------------+
  |                       E-Commerce OLTP System                                |
  |                                                                             |
  |   (( Register / Login )) <----------------------+                           |
  |                                                 |                           |
  |   (( Browse Products & View Stock )) <----+     |                           |
  |                                           |     |                           |
  |   (( Add Items to Cart )) <-----------+   |     |                           |
  |                                       |   |     |                           |
  |   (( Execute Atomic Checkout )) <--- (Customer) |                           |
  |                |                      |         |                           |
  |                | <<includes>>         |         |                           |
  |                v                      |         |                           |
  |   (( Deduct Warehouse Stock )) <------+         |                           |
  |                |                                |                           |
  |                | <<triggers>>                   |                           |
  |                v                                |                           |
  |   (( Write Immutable Audit Trail ))             |                           |
  |                ^                                |                           |
  |                | <<triggers>>                   |                           |
  |                |                                |                           |
  |   (( Cancel Order & Restock )) <------+         |                           |
  |                                       |         |                           |
  |   (( Manage Product Catalog )) <------+-------(Seller)                      |
  |                                       |                                     |
  |   (( View Sales & Inventory Status )) +                                     |
  +-----------------------------------------------------------------------------+
```
*Fig. 5. System Use Case Diagram*

#### 4.2.3 Class Diagram and Relational Schema
The relational database schema is structured in strict Third Normal Form (3NF) to eliminate insertion, update, and deletion anomalies. Figure 6 shows the Entity-Relationship and Class structure.

```
+---------------------+           +------------------------+
|      CUSTOMERS      |           |        SELLERS         |
+---------------------+           +------------------------+
| PK customer_id      |           | PK seller_id           |
|    first_name       |           |    business_name       |
|    last_name        |           |    contact_email (U)   |
|    email (U)        |           |    password_hash       |
|    password_hash    |           |    state_code (FK)     |
|    state_code (FK)  |           |    rating              |
+----------+----------+           +-----------+------------+
           | 1                                | 1
           |                                  |
           | N                                | N
+----------v----------+           +-----------v------------+
|       ORDERS        |           |        PRODUCTS        |
+---------------------+           +------------------------+
| PK order_id         |           | PK product_id          |
| FK customer_id      |           | FK seller_id           |
| FK seller_id        |           | FK category_id         |
|    order_status     |           |    product_name        |
|    total_amount     |           |    unit_price          |
|    shipping_addr    |           |    weight_kg           |
+----+-------------+--+           +----+--------------+----+
     | 1           | 1                 | 1            | 1
     |             |                   |              |
     | N           | 1                 | N            | N
+----v-------+  +--v----------+  +-----v-------+  +---v---------------+
|ORDER_ITEMS |  |  PAYMENTS   |  |  INVENTORY  |  |  INVENTORY_AUDIT  |
+------------+  +-------------+  +-------------+  +-------------------+
|PK item_id  |  |PK payment_id|  |PK inv_id    |  |PK audit_id        |
|FK order_id |  |FK order_id  |  |FK product_id|  |FK inv_id          |
|FK prod_id  |  |   method    |  |   wh_state  |  |FK product_id      |
|   quantity |  |   status    |  |   stock_qty |  |   qty_before      |
|   subtotal |  |   amount    |  |   reorder   |  |   qty_deducted    |
+------------+  +-------------+  +-------------+  |   action          |
                                                  +-------------------+
```
*Fig. 6. Relational Entity-Relationship & Class Structure*

**Schema Integrity Highlights:**
- **Composite Unique Keys:** `inventory(product_id, warehouse_state)` prevents duplicate warehouse mappings for the same product.
- **Computed Subtotals:** `order_items.subtotal` uses `GENERATED ALWAYS AS (quantity * unit_price) STORED`, preserving 3NF by calculating values at write-time without manual maintenance.
- **Pessimistic Check Constraints:** `CHECK (stock_quantity >= 0)` enforces an absolute physical barrier against negative stock at the engine storage level.

#### 4.2.4 Sequence Diagram
Figure 7 details the chronological execution sequence of a concurrent checkout transaction, illustrating how row-level locks prevent race conditions.

```
Customer/UI         FastAPI API          PostgreSQL Engine       Inventory Table       Audit Table
     |                   |                       |                      |                   |
     |-- POST /checkout->|                       |                      |                   |
     |   (Cart Items)    |-- process_checkout()->|                      |                   |
     |                   |   (cart_item[] array) |                      |                   |
     |                   |                       |-- Validate Cart ---->|                   |
     |                   |                       |-- INSERT order ----->|                   |
     |                   |                       |                      |                   |
     |                   |                       |-- INSERT item ------>|                   |
     |                   |                       |   (Fires Trigger)    |                   |
     |                   |                       |                      |                   |
     |                   |                       |-- SELECT FOR UPDATE->|                   |
     |                   |                       |   [EXCLUSIVE ROW LOCK]                   |
     |                   |                       |   (Concurrent TXs wait)                  |
     |                   |                       |                      |                   |
     |                   |                       |-- Deduct Stock ----->|                   |
     |                   |                       |   (stock = stock - q)|                   |
     |                   |                       |                      |                   |
     |                   |                       |-- Log Deduction ------------------------>|
     |                   |                       |                      |  (Append Ledger)  |
     |                   |                       |-- Record Payment --->|                   |
     |                   |                       |-- Create Shipment -->|                   |
     |                   |                       |-- COMMIT TRANSACTION |                   |
     |                   |                       |   (Locks Released)   |                   |
     |                   |<- Result (Order #1) --|                      |                   |
     |<- 200 OK (Success)|                       |                      |                   |
```
*Fig. 7. Sequence Diagram of Atomic Checkout and Trigger Execution*

---

# 5. REFERENCES

### Weblinks:
1. PostgreSQL Global Development Group, "PostgreSQL 18 Documentation: Concurrency Control and MVCC," Available: https://www.postgresql.org/docs/current/mvcc.html.
2. FastAPI Framework Documentation, "Concurrency, async / await, and High Performance," Available: https://fastapi.tiangolo.com/async/.
3. MagicStack Inc., "asyncpg: A Fast PostgreSQL Database Client Library for Python/asyncio," Available: https://github.com/MagicStack/asyncpg.

### Journals: <IEEE Format>
1. J. Gray, R. Lorie, G. R. Putzolu, and I. L. Traiger, "Granularity of Locks and Degrees of Consistency in a Shared Data Base," *ACM Transactions on Database Systems*, Vol. 1, No. 3, pp. 248-260, 1976.
2. H. Berenson, P. Bernstein, J. Gray, J. Melton, E. O'Neil, and P. O'Neil, "A Critique of ANSI SQL Isolation Levels," *ACM SIGMOD Record*, Vol. 24, No. 2, pp. 1-10, 1995.
3. D. R. K. Ports and K. Grittner, "Serializable Snapshot Isolation in PostgreSQL," *Proceedings of the VLDB Endowment*, Vol. 5, No. 12, pp. 1850-1861, 2012.
4. M. Stonebraker and R. Cattell, "10 Rules for Scalable High-Performance Database Systems," *Communications of the ACM*, Vol. 54, No. 10, pp. 72-83, 2011.

### Conference: <IEEE Format>
1. K. Daudjee and K. Salem, "Lazy Database Replication with Snapshot Isolation," in *2006 IEEE 22nd International Conference on Data Engineering (ICDE'06)*, Atlanta, GA, USA, 2006, pp. 33-33.
2. C. Mohan, "Repeating History Beyond ARIES," in *Proceedings of the 25th International Conference on Very Large Data Bases (VLDB'99)*, Edinburgh, Scotland, 1999, pp. 1-17.

### Books:
1. A. Silberschatz, H. F. Korth, and S. Sudarshan, *Database System Concepts*, 7th ed., New York, NY, USA: McGraw-Hill Education, 2020.
2. R. Ramakrishnan and J. Gehrke, *Database Management Systems*, 3rd ed., Boston, MA, USA: McGraw-Hill, 2003.
