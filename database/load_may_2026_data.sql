-- Load May 2026 data and refresh all views
-- Run this script to update the database with new May 2026 data

-- First, ensure the May 2026 data file exists and is loaded
-- If you have a new anonymised_summary_May_2026.sql file, replace the existing one first

\echo 'Loading May 2026 data...'
\i service_express_uk/anonymised_summary_May_2026.sql

-- Refresh all materialized views and common views
\echo 'Refreshing views...'

-- Refresh the base views that depend on the new data
CREATE OR REPLACE VIEW v_contract_summary AS
SELECT 
    c.extract_month,
    c.customer_name,
    c.account_manager,
    c.segment,
    c.sub_segment,
    c.contract_number,
    c.line_of_business,
    c.contract_end,
    c.contract_length_months,
    c.contract_length_label,
    c.invoice_frequency_months,
    c.contract_total_monthly,
    c.discount_applied,
    c.discount_pct,
    COUNT(cs.service_name) as service_count,
    STRING_AGG(cs.service_name, ', ' ORDER BY cs.monthly_total DESC) as services_used
FROM contracts c
LEFT JOIN contract_services cs ON c.id = cs.contract_id
LEFT JOIN extract_months em ON c.extract_month_id = em.id
WHERE em.extract_month = '2026-05'
GROUP BY c.id, c.extract_month, c.customer_name, c.account_manager, c.segment, c.sub_segment, 
         c.contract_number, c.line_of_business, c.contract_end, c.contract_length_months, 
         c.contract_length_label, c.invoice_frequency_months, c.contract_total_monthly, 
         c.discount_applied, c.discount_pct
ORDER BY c.contract_total_monthly DESC;

CREATE OR REPLACE VIEW v_service_breakdown AS
SELECT 
    em.extract_month,
    c.customer_name,
    cs.service_name,
    cs.service_line,
    cs.quantity,
    cs.monthly_total,
    c.contract_number,
    c.account_manager
FROM contracts c
JOIN contract_services cs ON c.id = cs.contract_id
JOIN extract_months em ON c.extract_month_id = em.id
WHERE em.extract_month = '2026-05'
ORDER BY cs.monthly_total DESC;

CREATE OR REPLACE VIEW v_customer_portfolio_latest AS
SELECT 
    c.customer_name,
    c.account_manager,
    c.segment,
    c.sub_segment,
    COUNT(DISTINCT c.contract_number) as contract_count,
    SUM(c.contract_total_monthly) as total_monthly_value,
    AVG(c.contract_total_monthly) as avg_monthly_value,
    MIN(c.contract_total_monthly) as min_monthly_value,
    MAX(c.contract_total_monthly) as max_monthly_value,
    SUM(CASE WHEN c.discount_applied THEN 1 ELSE 0 END) as discounted_contracts,
    AVG(CASE WHEN c.discount_applied THEN c.discount_pct ELSE 0 END) as avg_discount_pct
FROM contracts c
JOIN extract_months em ON c.extract_month_id = em.id
WHERE em.extract_month = '2026-05'
GROUP BY c.customer_name, c.account_manager, c.segment, c.sub_segment
ORDER BY total_monthly_value DESC;

-- Now refresh all the analytical views
\i common_views.sql

-- Verify the data was loaded correctly
\echo 'Verifying May 2026 data load...'
SELECT 
    'May 2026' as month_loaded,
    COUNT(DISTINCT customer_name) as customers,
    COUNT(DISTINCT contract_number) as contracts,
    SUM(contract_total_monthly) as total_monthly_revenue,
    COUNT(DISTINCT service_name) as unique_services
FROM v_contract_summary;

\echo 'May 2026 data load complete!'
