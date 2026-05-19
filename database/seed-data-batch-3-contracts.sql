-- =============================================================================
-- BATCH 3: Contracts (~2000 records)
-- Generates realistic contracts linking customers to providers via managers
-- Depends on: Batch 1, Batch 2
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_customer_count INTEGER;
    v_provider_count INTEGER;
    v_manager_count INTEGER;
    v_contract_types TEXT[] := ARRAY['Subscription', 'License', 'Services', 'Support', 'Managed Service'];
    v_statuses TEXT[] := ARRAY['Active', 'Active', 'Active', 'Active', 'Active', 'Expired', 'Renewed', 'Pending Renewal', 'Terminated'];
    v_payment_terms TEXT[] := ARRAY['Net 30', 'Net 30', 'Net 45', 'Net 60', 'Net 30'];
    v_customer_id INTEGER;
    v_provider_id INTEGER;
    v_manager_id INTEGER;
    v_contract_type TEXT;
    v_status TEXT;
    v_start_date DATE;
    v_end_date DATE;
    v_annual_value NUMERIC;
    v_duration_years INTEGER;
    v_ref TEXT;
    v_year INTEGER;
    i INTEGER;
    v_cust_segment TEXT;
BEGIN
    SELECT COUNT(*) INTO v_customer_count FROM customers;
    SELECT COUNT(*) INTO v_provider_count FROM providers;
    SELECT COUNT(*) INTO v_manager_count FROM account_managers;

    -- Generate ~2000 contracts: ~10 contracts per customer on average
    FOR i IN 1..2000 LOOP
        -- Pick random customer
        SELECT customer_id, segment INTO v_customer_id, v_cust_segment
        FROM customers
        ORDER BY random()
        LIMIT 1;

        -- Pick random provider
        SELECT provider_id INTO v_provider_id
        FROM providers
        ORDER BY random()
        LIMIT 1;

        -- Pick random manager (weighted by region match would be ideal but random is fine)
        SELECT manager_id INTO v_manager_id
        FROM account_managers
        WHERE is_active = TRUE
        ORDER BY random()
        LIMIT 1;

        -- Contract type
        v_contract_type := v_contract_types[1 + floor(random() * array_length(v_contract_types, 1))::int];

        -- Status
        v_status := v_statuses[1 + floor(random() * array_length(v_statuses, 1))::int];

        -- Start date: 2019-2024
        v_year := 2019 + floor(random() * 6)::int;
        v_start_date := make_date(v_year, 1 + floor(random() * 12)::int, 1 + floor(random() * 28)::int);

        -- Duration: 1-5 years
        v_duration_years := 1 + floor(random() * 5)::int;
        v_end_date := v_start_date + (v_duration_years * 365);

        -- Annual value based on segment and contract type
        CASE v_cust_segment
            WHEN 'Enterprise' THEN
                v_annual_value := (random() * 2000000 + 200000);  -- 200K - 2.2M
            WHEN 'Mid-Market' THEN
                v_annual_value := (random() * 500000 + 50000);    -- 50K - 550K
            WHEN 'SMB' THEN
                v_annual_value := (random() * 80000 + 12000);     -- 12K - 92K
            WHEN 'Public Sector' THEN
                v_annual_value := (random() * 800000 + 100000);   -- 100K - 900K
            WHEN 'Healthcare' THEN
                v_annual_value := (random() * 1200000 + 150000);  -- 150K - 1.35M
            ELSE
                v_annual_value := (random() * 500000 + 50000);
        END CASE;

        -- Support/Services are typically lower value
        IF v_contract_type IN ('Support', 'Services') THEN
            v_annual_value := v_annual_value * 0.4;
        END IF;

        -- Generate contract reference
        v_ref := 'CTR-' || v_year::text || '-' || lpad(i::text, 5, '0');

        INSERT INTO contracts (
            contract_ref, customer_id, provider_id, manager_id,
            contract_type, start_date, end_date,
            annual_value_usd, total_contract_value,
            status, auto_renew, payment_terms
        ) VALUES (
            v_ref,
            v_customer_id,
            v_provider_id,
            v_manager_id,
            v_contract_type,
            v_start_date,
            v_end_date,
            round(v_annual_value, 2),
            round(v_annual_value * v_duration_years, 2),
            v_status,
            random() > 0.4,  -- 60% have auto-renew
            v_payment_terms[1 + floor(random() * array_length(v_payment_terms, 1))::int]
        );
    END LOOP;
END $$;

COMMIT;

-- Verify
SELECT status, COUNT(*) AS count, 
       ROUND(SUM(annual_value_usd)/1000000, 2) AS total_annual_value_millions
FROM contracts 
GROUP BY status 
ORDER BY count DESC;
