-- Refresh all views for May 2026 data
-- Run this to fix the views after data is loaded

-- Refresh the base views that depend on the new data
CREATE OR REPLACE VIEW v_contract_summary AS
SELECT 
    em.extract_month,
    cu.display_name as customer_name,
    cu.account_manager,
    cu.segment,
    cu.sub_segment,
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
LEFT JOIN customers cu ON c.customer_id = cu.id
WHERE em.extract_month = '2026-05'
GROUP BY c.id, em.extract_month, cu.display_name, cu.account_manager, cu.segment, cu.sub_segment, 
         c.contract_number, c.line_of_business, c.contract_end, c.contract_length_months, 
         c.contract_length_label, c.invoice_frequency_months, c.contract_total_monthly, 
         c.discount_applied, c.discount_pct
ORDER BY c.contract_total_monthly DESC;

CREATE OR REPLACE VIEW v_service_breakdown AS
SELECT 
    em.extract_month,
    cu.display_name as customer_name,
    cs.service_name,
    cs.service_line,
    cs.quantity,
    cs.monthly_total,
    c.contract_number,
    cu.account_manager
FROM contracts c
JOIN contract_services cs ON c.id = cs.contract_id
JOIN extract_months em ON c.extract_month_id = em.id
LEFT JOIN customers cu ON c.customer_id = cu.id
WHERE em.extract_month = '2026-05'
ORDER BY cs.monthly_total DESC;

CREATE OR REPLACE VIEW v_customer_portfolio_latest AS
SELECT 
    cu.display_name as customer_name,
    cu.account_manager,
    cu.segment,
    cu.sub_segment,
    COUNT(DISTINCT c.contract_number) as contract_count,
    SUM(c.contract_total_monthly) as total_monthly_value,
    AVG(c.contract_total_monthly) as avg_monthly_value,
    MIN(c.contract_total_monthly) as min_monthly_value,
    MAX(c.contract_total_monthly) as max_monthly_value,
    SUM(CASE WHEN c.discount_applied THEN 1 ELSE 0 END) as discounted_contracts,
    AVG(CASE WHEN c.discount_applied THEN c.discount_pct ELSE 0 END) as avg_discount_pct
FROM contracts c
JOIN extract_months em ON c.extract_month_id = em.id
LEFT JOIN customers cu ON c.customer_id = cu.id
WHERE em.extract_month = '2026-05'
GROUP BY cu.display_name, cu.account_manager, cu.segment, cu.sub_segment
ORDER BY total_monthly_value DESC;

-- Now refresh all the analytical views
\i /tmp/common_views.sql

-- Verify the views work
\echo 'Testing views...'
SELECT 'May 2026 data verified' as status,
       (SELECT COUNT(*) FROM v_contract_summary WHERE extract_month = '2026-05') as contracts,
       (SELECT COUNT(DISTINCT customer_name) FROM v_contract_summary WHERE extract_month = '2026-05') as customers,
       (SELECT COUNT(DISTINCT service_name) FROM v_service_breakdown WHERE extract_month = '2026-05') as services;
