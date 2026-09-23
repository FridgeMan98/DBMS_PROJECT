-- =============================================================
-- 02_order_status_audit_trigger.sql
-- Fires AFTER UPDATE on orders.order_status.
-- Logs every lifecycle transition into order_status_audit.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_audit_order_status()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Only log if status actually changed
    IF NEW.order_status IS DISTINCT FROM OLD.order_status THEN
        INSERT INTO order_status_audit (
            order_id,
            old_status,
            new_status,
            changed_at,
            changed_by_user
        ) VALUES (
            NEW.order_id,
            OLD.order_status,
            NEW.order_status,
            NOW(),
            current_user
        );

        -- Also update the updated_at timestamp on orders
        NEW.updated_at := NOW();
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_order_status ON orders;

CREATE TRIGGER trg_audit_order_status
BEFORE UPDATE OF order_status ON orders
FOR EACH ROW
EXECUTE FUNCTION fn_audit_order_status();

\echo '--> Order status audit trigger created.'