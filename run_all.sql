-- =============================================================
-- run_all.sql — Master Runner Script
-- Execute with: psql -U postgres -d ecommerce_db -f run_all.sql
-- =============================================================

\echo '=========================================='
\echo ' E-Commerce OLTP Engine — Full Setup'
\echo '=========================================='

\echo ''
\echo '[1/5] Running Schema...'
\i schema/create_tables.sql
\i schema/create_indexes.sql
\i schema/seed_data.sql

\echo ''
\echo '[2/5] Running Triggers...'
\i triggers/inventory_deduction_trigger.sql
\i triggers/order_status_audit_trigger.sql

\echo ''
\echo '[3/5] Running Stored Procedures...'
\i procedures/process_order_checkout.sql
\i procedures/calculate_estimated_delivery.sql
\i procedures/process_order_cancellation.sql

\echo ''
\echo '[4/5] Running Transaction & Concurrency Config...'
\i transactions/isolation_level_config.sql
\i transactions/concurrency_test.sql

\echo ''
\echo '[5/5] Running Tests...'
\i tests/happy_path_test.sql
\i tests/oversell_test.sql
\i tests/cancellation_test.sql
\i tests/audit_log_verification.sql

\echo ''
\echo '=========================================='
\echo ' Setup Complete.'
\echo '=========================================='