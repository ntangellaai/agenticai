-- =============================================================================
-- BATCH 5: Spend History (~2000+ records)
-- Generates quarterly spend records for each active contract
-- Depends on: Batch 2 (customers), Batch 3 (contracts)
-- =============================================================================

BEGIN;

-- Generate quarterly spend records for all contracts
-- Each contract generates one spend record per quarter it was active
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count)
SELECT
    c.customer_id,
    ct.contract_id,
    yr.fiscal_year,
    qtr.fiscal_quarter,
    -- Quarterly amount = annual_value / 4, with some variance (+/- 10%)
    round(
        ((ct.annual_value_usd / 4.0) * (0.9 + random() * 0.2))::numeric,
        2
    ) AS amount_usd,
    -- Category matches contract type
    CASE ct.contract_type
        WHEN 'Subscription' THEN 'Software'
        WHEN 'License' THEN 'Software'
        WHEN 'Services' THEN 'Professional Services'
        WHEN 'Support' THEN 'Support & Maintenance'
        WHEN 'Managed Service' THEN 'Managed Services'
        ELSE 'Other'
    END AS category,
    -- Invoice count: 1-5 per quarter depending on contract size
    CASE
        WHEN ct.annual_value_usd > 1000000 THEN 3 + floor(random() * 3)::int
        WHEN ct.annual_value_usd > 500000 THEN 2 + floor(random() * 2)::int
        WHEN ct.annual_value_usd > 100000 THEN 1 + floor(random() * 2)::int
        ELSE 1
    END AS invoice_count
FROM contracts ct
JOIN customers c ON ct.customer_id = c.customer_id
CROSS JOIN generate_series(2021, 2024) AS yr(fiscal_year)
CROSS JOIN generate_series(1, 4) AS qtr(fiscal_quarter)
WHERE
    -- Only generate spend for quarters the contract was active
    make_date(yr.fiscal_year, (qtr.fiscal_quarter - 1) * 3 + 1, 1) >= ct.start_date
    AND make_date(yr.fiscal_year, (qtr.fiscal_quarter - 1) * 3 + 1, 1) < ct.end_date
    -- Only for contracts that are Active, Renewed, or Pending Renewal
    AND ct.status IN ('Active', 'Renewed', 'Pending Renewal', 'Expired');

COMMIT;

-- Verify
SELECT fiscal_year, COUNT(*) AS records,
       ROUND(SUM(amount_usd)/1000000, 2) AS total_spend_millions
FROM spend_history 
GROUP BY fiscal_year 
ORDER BY fiscal_year;
