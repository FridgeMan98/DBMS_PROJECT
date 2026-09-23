-- =============================================================
-- 02_calculate_estimated_delivery.sql
-- Function: calculate_estimated_delivery_date
--
-- Computes ETA based on seller state → customer state routing.
-- Logic:
--   Same state          → 2 business days
--   Adjacent/nearby     → 4 business days
--   Cross-region        → 7 business days
--
-- Returns: estimated delivery DATE from today
-- =============================================================

CREATE OR REPLACE FUNCTION calculate_estimated_delivery_date(
    p_seller_state_code   CHAR(2),
    p_customer_state_code CHAR(2)
)
RETURNS DATE
LANGUAGE plpgsql
AS $$
DECLARE
    v_days_to_add       INT;

    -- Region groupings (South, West, North, East)
    south_states        CHAR(2)[] := ARRAY['TN','KA','KL','AP','TS'];
    west_states         CHAR(2)[] := ARRAY['MH','GJ'];
    north_states        CHAR(2)[] := ARRAY['DL','RJ'];
    east_states         CHAR(2)[] := ARRAY['WB'];
BEGIN
    IF p_seller_state_code IS NULL OR p_customer_state_code IS NULL THEN
        -- Fallback if state data is missing
        RETURN CURRENT_DATE + INTERVAL '5 days';
    END IF;

    -- Same state → fastest
    IF p_seller_state_code = p_customer_state_code THEN
        v_days_to_add := 2;

    -- Same region → medium
    ELSIF (p_seller_state_code = ANY(south_states)   AND p_customer_state_code = ANY(south_states))
       OR (p_seller_state_code = ANY(west_states)    AND p_customer_state_code = ANY(west_states))
       OR (p_seller_state_code = ANY(north_states)   AND p_customer_state_code = ANY(north_states))
       OR (p_seller_state_code = ANY(east_states)    AND p_customer_state_code = ANY(east_states))
    THEN
        v_days_to_add := 4;

    -- Cross-region → slowest
    ELSE
        v_days_to_add := 7;
    END IF;

    RETURN CURRENT_DATE + (v_days_to_add || ' days')::INTERVAL;
END;
$$;

\echo '  [OK] calculate_estimated_delivery_date() created.'