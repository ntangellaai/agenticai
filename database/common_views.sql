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

-- Grant permissions
GRANT SELECT ON v_revenue_by_segment TO mcp_readonly;
GRANT SELECT ON v_account_manager_performance TO mcp_readonly;
GRANT SELECT ON v_service_revenue_summary TO mcp_readonly;
GRANT SELECT ON v_renewal_urgency TO mcp_readonly;
GRANT SELECT ON v_executive_summary TO mcp_readonly;
GRANT SELECT ON v_discount_analysis TO mcp_readonly;
GRANT SELECT ON v_top_customers TO mcp_readonly;
GRANT SELECT ON v_customer_service_mix TO mcp_readonly;
