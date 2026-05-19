-- =============================================================================
-- Business Views for Enterprise Contracts
-- These views simplify common agent queries
-- =============================================================================

-- Customer overview with contract summary
CREATE OR REPLACE VIEW v_customer_overview AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.segment,
    c.industry,
    c.region,
    c.status AS customer_status,
    c.annual_revenue_usd,
    COUNT(DISTINCT ct.contract_id) AS total_contracts,
    COUNT(DISTINCT ct.contract_id) FILTER (WHERE ct.status = 'Active') AS active_contracts,
    SUM(ct.annual_value_usd) FILTER (WHERE ct.status = 'Active') AS total_active_annual_value,
    MIN(ct.start_date) AS first_contract_date,
    MAX(ct.end_date) AS latest_contract_end
FROM customers c
LEFT JOIN contracts ct ON c.customer_id = ct.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment, c.industry, c.region, 
         c.status, c.annual_revenue_usd;

-- Contract details with customer and provider names
CREATE OR REPLACE VIEW v_contract_details AS
SELECT 
    ct.contract_id,
    ct.contract_ref,
    c.customer_name,
    c.segment,
    p.provider_name,
    p.provider_type,
    am.manager_name,
    ct.contract_type,
    ct.start_date,
    ct.end_date,
    ct.annual_value_usd,
    ct.total_contract_value,
    ct.status,
    ct.auto_renew,
    (ct.end_date - CURRENT_DATE) AS days_until_expiry
FROM contracts ct
JOIN customers c ON ct.customer_id = c.customer_id
JOIN providers p ON ct.provider_id = p.provider_id
JOIN account_managers am ON ct.manager_id = am.manager_id;

-- Annual spend by customer
CREATE OR REPLACE VIEW v_annual_customer_spend AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.segment,
    sh.fiscal_year,
    SUM(sh.amount_usd) AS annual_spend,
    SUM(sh.invoice_count) AS total_invoices,
    LAG(SUM(sh.amount_usd)) OVER (PARTITION BY c.customer_id ORDER BY sh.fiscal_year) AS prev_year_spend,
    CASE 
        WHEN LAG(SUM(sh.amount_usd)) OVER (PARTITION BY c.customer_id ORDER BY sh.fiscal_year) > 0
        THEN ROUND(
            (SUM(sh.amount_usd) - LAG(SUM(sh.amount_usd)) OVER (PARTITION BY c.customer_id ORDER BY sh.fiscal_year))
            / LAG(SUM(sh.amount_usd)) OVER (PARTITION BY c.customer_id ORDER BY sh.fiscal_year) * 100, 2
        )
        ELSE NULL
    END AS yoy_growth_pct
FROM customers c
JOIN spend_history sh ON c.customer_id = sh.customer_id
GROUP BY c.customer_id, c.customer_name, c.segment, sh.fiscal_year;

-- Renewal risk dashboard
CREATE OR REPLACE VIEW v_renewal_risk_dashboard AS
SELECT 
    rr.risk_id,
    ct.contract_ref,
    c.customer_name,
    c.segment,
    ct.annual_value_usd,
    ct.end_date,
    (ct.end_date - CURRENT_DATE) AS days_until_expiry,
    rr.risk_score,
    rr.risk_factors,
    rr.recommended_action,
    rr.status AS risk_status,
    am.manager_name
FROM renewal_risks rr
JOIN contracts ct ON rr.contract_id = ct.contract_id
JOIN customers c ON ct.customer_id = c.customer_id
JOIN account_managers am ON ct.manager_id = am.manager_id
WHERE rr.status = 'Open'
ORDER BY rr.risk_score DESC;

-- Account manager portfolio
CREATE OR REPLACE VIEW v_manager_portfolio AS
SELECT 
    am.manager_id,
    am.manager_name,
    am.region,
    am.team,
    COUNT(DISTINCT ct.contract_id) AS total_contracts,
    COUNT(DISTINCT ct.customer_id) AS total_customers,
    SUM(ct.annual_value_usd) FILTER (WHERE ct.status = 'Active') AS managed_revenue,
    AVG(ct.annual_value_usd) FILTER (WHERE ct.status = 'Active') AS avg_contract_value,
    COUNT(*) FILTER (WHERE ct.status = 'Pending Renewal') AS pending_renewals,
    COUNT(DISTINCT rr.risk_id) FILTER (WHERE rr.status = 'Open') AS open_risks
FROM account_managers am
LEFT JOIN contracts ct ON am.manager_id = ct.manager_id
LEFT JOIN renewal_risks rr ON ct.contract_id = rr.contract_id
WHERE am.is_active = TRUE
GROUP BY am.manager_id, am.manager_name, am.region, am.team;

-- Provider concentration analysis
CREATE OR REPLACE VIEW v_provider_concentration AS
SELECT 
    p.provider_id,
    p.provider_name,
    p.provider_type,
    p.tier,
    COUNT(DISTINCT ct.contract_id) AS contract_count,
    COUNT(DISTINCT ct.customer_id) AS customer_count,
    SUM(ct.annual_value_usd) AS total_annual_value,
    ROUND(SUM(ct.annual_value_usd) * 100.0 / 
        NULLIF((SELECT SUM(annual_value_usd) FROM contracts WHERE status = 'Active'), 0), 2
    ) AS pct_of_total_spend
FROM providers p
JOIN contracts ct ON p.provider_id = ct.provider_id
WHERE ct.status = 'Active'
GROUP BY p.provider_id, p.provider_name, p.provider_type, p.tier
ORDER BY total_annual_value DESC;

-- Support tickets impact (high-revenue customers with many tickets)
CREATE OR REPLACE VIEW v_support_revenue_risk AS
SELECT 
    c.customer_id,
    c.customer_name,
    c.segment,
    SUM(ct.annual_value_usd) FILTER (WHERE ct.status = 'Active') AS active_revenue,
    COUNT(DISTINCT st.ticket_id) AS total_tickets,
    COUNT(DISTINCT st.ticket_id) FILTER (WHERE st.severity IN ('Critical', 'High')) AS high_sev_tickets,
    COUNT(DISTINCT st.ticket_id) FILTER (WHERE st.status IN ('Open', 'Escalated')) AS open_tickets,
    AVG(st.resolution_hours) AS avg_resolution_hours
FROM customers c
LEFT JOIN contracts ct ON c.customer_id = ct.customer_id
LEFT JOIN support_tickets st ON c.customer_id = st.customer_id
    AND st.opened_date >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY c.customer_id, c.customer_name, c.segment
HAVING COUNT(DISTINCT st.ticket_id) > 0;

-- Segment summary
CREATE OR REPLACE VIEW v_segment_summary AS
SELECT 
    c.segment,
    COUNT(DISTINCT c.customer_id) AS customer_count,
    COUNT(DISTINCT ct.contract_id) FILTER (WHERE ct.status = 'Active') AS active_contracts,
    SUM(ct.annual_value_usd) FILTER (WHERE ct.status = 'Active') AS segment_revenue,
    AVG(ct.annual_value_usd) FILTER (WHERE ct.status = 'Active') AS avg_contract_value,
    COUNT(DISTINCT rr.risk_id) FILTER (WHERE rr.status = 'Open') AS open_risks
FROM customers c
LEFT JOIN contracts ct ON c.customer_id = ct.customer_id
LEFT JOIN renewal_risks rr ON ct.contract_id = rr.contract_id
GROUP BY c.segment;

-- Grant SELECT on views to mcp_readonly
GRANT SELECT ON v_customer_overview TO mcp_readonly;
GRANT SELECT ON v_contract_details TO mcp_readonly;
GRANT SELECT ON v_annual_customer_spend TO mcp_readonly;
GRANT SELECT ON v_renewal_risk_dashboard TO mcp_readonly;
GRANT SELECT ON v_manager_portfolio TO mcp_readonly;
GRANT SELECT ON v_provider_concentration TO mcp_readonly;
GRANT SELECT ON v_support_revenue_risk TO mcp_readonly;
GRANT SELECT ON v_segment_summary TO mcp_readonly;
