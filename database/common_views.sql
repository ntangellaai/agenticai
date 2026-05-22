-- Common Views for Service Express UK
-- These eliminate the need for LLM to write SQL for frequent questions

-- View 1: Revenue by customer segment (for "revenue by segment" questions)
CREATE OR REPLACE VIEW v_revenue_by_segment AS
SELECT 
    segment,
    COUNT(DISTINCT customer_name) as customer_count,
    SUM(contract_count) as contract_count,
    SUM(total_monthly_value) as total_monthly_revenue,
    AVG(total_monthly_value) as avg_monthly_revenue,
    MIN(total_monthly_value) as min_monthly_revenue,
    MAX(total_monthly_value) as max_monthly_revenue
FROM v_customer_portfolio_latest
GROUP BY segment
ORDER BY total_monthly_revenue DESC;

-- View 2: Account manager performance (for "best AM" questions)
CREATE OR REPLACE VIEW v_account_manager_performance AS
SELECT 
    account_manager,
    COUNT(DISTINCT customer_name) as customers_managed,
    COUNT(DISTINCT contract_number) as contracts_managed,
    SUM(contract_total_monthly) as total_revenue,
    AVG(contract_total_monthly) as avg_contract_value,
    SUM(CASE WHEN discount_applied THEN 1 ELSE 0 END) as discounted_contracts,
    AVG(CASE WHEN discount_applied THEN discount_pct ELSE 0 END) as avg_discount_pct
FROM v_contract_summary
WHERE account_manager IS NOT NULL AND account_manager != ''
GROUP BY account_manager
ORDER BY total_revenue DESC;

-- View 3: Service revenue summary (for "top services" questions)
CREATE OR REPLACE VIEW v_service_revenue_summary AS
SELECT 
    service_name,
    COUNT(DISTINCT customer_name) as customer_count,
    COUNT(DISTINCT contract_number) as contract_count,
    SUM(monthly_total) as total_monthly_revenue,
    SUM(quantity) as total_quantity,
    AVG(monthly_total) as avg_monthly_per_contract
FROM v_service_breakdown
GROUP BY service_name
ORDER BY total_monthly_revenue DESC;

-- View 4: Contract renewal urgency (for "renewals" questions)
CREATE OR REPLACE VIEW v_renewal_urgency AS
SELECT 
    CASE 
        WHEN days_to_renewal <= 30 THEN 'Critical (0-30 days)'
        WHEN days_to_renewal <= 60 THEN 'Urgent (31-60 days)'
        WHEN days_to_renewal <= 90 THEN 'Upcoming (61-90 days)'
        ELSE 'Future (90+ days)'
    END as urgency_bucket,
    COUNT(*) as contract_count,
    COUNT(DISTINCT customer_name) as customer_count,
    SUM(contract_total_monthly) as total_monthly_value,
    AVG(days_to_renewal) as avg_days_to_renewal
FROM v_renewal_pipeline
GROUP BY 
    CASE 
        WHEN days_to_renewal <= 30 THEN 'Critical (0-30 days)'
        WHEN days_to_renewal <= 60 THEN 'Urgent (31-60 days)'
        WHEN days_to_renewal <= 90 THEN 'Upcoming (61-90 days)'
        ELSE 'Future (90+ days)'
    END
ORDER BY MIN(days_to_renewal);

-- View 5: Customer portfolio summary (for "executive summary" questions)
CREATE OR REPLACE VIEW v_executive_summary AS
SELECT 
    (SELECT COUNT(DISTINCT customer_name) FROM v_customer_portfolio_latest) as total_customers,
    (SELECT COUNT(DISTINCT contract_number) FROM v_contract_summary) as total_contracts,
    (SELECT SUM(total_monthly_value) FROM v_customer_portfolio_latest) as total_monthly_revenue,
    (SELECT AVG(total_monthly_value) FROM v_customer_portfolio_latest) as avg_customer_value,
    (SELECT COUNT(*) FROM v_renewal_pipeline WHERE days_to_renewal <= 90) as renewals_90d,
    (SELECT COUNT(DISTINCT account_manager) FROM v_contract_summary WHERE account_manager IS NOT NULL) as total_account_managers;

-- View 6: Discount analysis (for "discount" questions)
CREATE OR REPLACE VIEW v_discount_analysis AS
SELECT 
    discount_applied,
    COUNT(*) as contract_count,
    COUNT(DISTINCT customer_name) as customer_count,
    SUM(contract_total_monthly) as total_monthly_value,
    AVG(CASE WHEN discount_applied THEN discount_pct ELSE NULL END) as avg_discount_pct,
    MIN(CASE WHEN discount_applied THEN discount_pct ELSE NULL END) as min_discount_pct,
    MAX(CASE WHEN discount_applied THEN discount_pct ELSE NULL END) as max_discount_pct
FROM v_contract_summary
GROUP BY discount_applied;

-- View 7: Top 10 customers pre-ranked (for "top customers" questions)
CREATE OR REPLACE VIEW v_top_customers AS
SELECT 
    customer_name,
    segment,
    account_manager,
    contract_count,
    total_monthly_value,
    earliest_renewal,
    latest_renewal,
    ROW_NUMBER() OVER (ORDER BY total_monthly_value DESC) as revenue_rank
FROM v_customer_portfolio_latest
ORDER BY total_monthly_value DESC;

-- View 8: Service mix by customer (for "what services does X use" questions)
CREATE OR REPLACE VIEW v_customer_service_mix AS
SELECT 
    customer_name,
    segment,
    COUNT(DISTINCT service_name) as service_count,
    STRING_AGG(DISTINCT service_name, ', ' ORDER BY service_name) as services_used,
    SUM(monthly_total) as total_service_revenue
FROM v_service_breakdown
GROUP BY customer_name, segment;

-- View 9: Service trends by month (for time-based trend analysis)
CREATE OR REPLACE VIEW v_service_monthly_trends AS
SELECT 
    extract_month,
    month_label,
    service_name,
    COUNT(DISTINCT customer_name) as customer_count,
    COUNT(DISTINCT contract_number) as contract_count,
    SUM(monthly_total) as monthly_revenue,
    SUM(quantity) as total_quantity
FROM v_service_breakdown
GROUP BY extract_month, month_label, service_name
ORDER BY extract_month DESC, monthly_revenue DESC;

-- View 10: Service performance last 6 months (for "most sold" questions)
CREATE OR REPLACE VIEW v_service_performance_6m AS
SELECT 
    service_name,
    SUM(monthly_revenue) as total_revenue_6m,
    AVG(monthly_revenue) as avg_monthly_revenue,
    MAX(customer_count) as peak_customers,
    MIN(customer_count) as min_customers,
    MAX(total_quantity) as total_quantity_sold,
    ROW_NUMBER() OVER (ORDER BY SUM(monthly_revenue) DESC) as revenue_rank
FROM v_service_monthly_trends
WHERE extract_month >= TO_CHAR(CURRENT_DATE - INTERVAL '6 months', 'YYYY-MM')
GROUP BY service_name
ORDER BY total_revenue_6m DESC;

-- View 11: Service decline analysis 12 months (for "declined most" questions)
CREATE OR REPLACE VIEW v_service_decline_12m AS
WITH first_6m AS (
    SELECT 
        service_name,
        SUM(monthly_revenue) as revenue_first_6m,
        AVG(customer_count) as customers_first_6m
    FROM v_service_monthly_trends
    WHERE extract_month >= TO_CHAR(CURRENT_DATE - INTERVAL '12 months', 'YYYY-MM')
      AND extract_month < TO_CHAR(CURRENT_DATE - INTERVAL '6 months', 'YYYY-MM')
    GROUP BY service_name
),
last_6m AS (
    SELECT 
        service_name,
        SUM(monthly_revenue) as revenue_last_6m,
        AVG(customer_count) as customers_last_6m
    FROM v_service_monthly_trends
    WHERE extract_month >= TO_CHAR(CURRENT_DATE - INTERVAL '6 months', 'YYYY-MM')
    GROUP BY service_name
)
SELECT 
    COALESCE(f.service_name, l.service_name) as service_name,
    f.revenue_first_6m,
    l.revenue_last_6m,
    f.revenue_first_6m - l.revenue_last_6m as revenue_decline,
    CASE WHEN f.revenue_first_6m > 0 
         THEN ROUND(((f.revenue_first_6m - l.revenue_last_6m) / f.revenue_first_6m * 100), 2)
         ELSE 0 
    END as revenue_decline_pct,
    f.customers_first_6m,
    l.customers_last_6m,
    COALESCE(f.customers_first_6m, 0) - COALESCE(l.customers_last_6m, 0) as customer_decline,
    ROW_NUMBER() OVER (ORDER BY f.revenue_first_6m - l.revenue_last_6m DESC) as decline_rank_revenue,
    ROW_NUMBER() OVER (ORDER BY COALESCE(f.customers_first_6m, 0) - COALESCE(l.customers_last_6m, 0) DESC) as decline_rank_customers
FROM first_6m f
FULL OUTER JOIN last_6m l ON f.service_name = l.service_name
WHERE f.revenue_first_6m > 0 OR l.revenue_last_6m > 0
ORDER BY revenue_decline DESC;

-- View 12: Low service customers (for "3 or fewer services" questions)
CREATE OR REPLACE VIEW v_low_service_customers AS
SELECT 
    csm.customer_name,
    csm.segment,
    cpl.account_manager,
    csm.service_count,
    csm.services_used,
    csm.total_service_revenue,
    CASE 
        WHEN csm.service_count = 1 THEN 'Single Service'
        WHEN csm.service_count <= 3 THEN 'Low (2-3 Services)'
        ELSE 'Multi-Service (4+)'
    END as service_category
FROM v_customer_service_mix csm
LEFT JOIN v_customer_portfolio_latest cpl ON csm.customer_name = cpl.customer_name
WHERE csm.service_count <= 3
ORDER BY csm.service_count, csm.total_service_revenue DESC;

-- View 13: Service count distribution (for quick stats)
CREATE OR REPLACE VIEW v_service_count_distribution AS
SELECT 
    service_category,
    COUNT(*) as customer_count,
    SUM(total_service_revenue) as total_revenue,
    AVG(total_service_revenue) as avg_revenue
FROM (
    SELECT 
        customer_name,
        total_service_revenue,
        CASE 
            WHEN service_count = 1 THEN 'Single Service'
            WHEN service_count <= 3 THEN 'Low (2-3 Services)'
            ELSE 'Multi-Service (4+)'
        END as service_category
    FROM v_customer_service_mix
) sub
GROUP BY service_category
ORDER BY customer_count DESC;

-- Grant permissions
GRANT SELECT ON v_revenue_by_segment TO mcp_readonly;
GRANT SELECT ON v_account_manager_performance TO mcp_readonly;
GRANT SELECT ON v_service_revenue_summary TO mcp_readonly;
GRANT SELECT ON v_renewal_urgency TO mcp_readonly;
GRANT SELECT ON v_executive_summary TO mcp_readonly;
GRANT SELECT ON v_discount_analysis TO mcp_readonly;
GRANT SELECT ON v_top_customers TO mcp_readonly;
GRANT SELECT ON v_customer_service_mix TO mcp_readonly;
GRANT SELECT ON v_service_monthly_trends TO mcp_readonly;
GRANT SELECT ON v_service_performance_6m TO mcp_readonly;
GRANT SELECT ON v_service_decline_12m TO mcp_readonly;
GRANT SELECT ON v_low_service_customers TO mcp_readonly;
GRANT SELECT ON v_service_count_distribution TO mcp_readonly;
