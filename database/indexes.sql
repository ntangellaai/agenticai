-- =============================================================================
-- Additional Performance Indexes
-- Applied after data load for optimal demo query performance
-- =============================================================================

-- Composite indexes for common query patterns

-- "Which contracts are expiring soon?" (agent's most common query)
CREATE INDEX IF NOT EXISTS idx_contracts_status_end_date 
    ON contracts(status, end_date) 
    WHERE status IN ('Active', 'Pending Renewal');

-- "Customer spend by year" (YoY comparison queries)
CREATE INDEX IF NOT EXISTS idx_spend_customer_year 
    ON spend_history(customer_id, fiscal_year, fiscal_quarter);

-- "High-value at-risk contracts" (renewal risk queries)
CREATE INDEX IF NOT EXISTS idx_contracts_value_status 
    ON contracts(annual_value_usd DESC, status);

-- "Support tickets for at-risk customers" (correlation queries)
CREATE INDEX IF NOT EXISTS idx_tickets_customer_date 
    ON support_tickets(customer_id, opened_date DESC);

-- "Contract events timeline" (change explanation queries)
CREATE INDEX IF NOT EXISTS idx_events_contract_date 
    ON contract_events(contract_id, event_date DESC);

-- "Manager portfolio value" (account manager queries)
CREATE INDEX IF NOT EXISTS idx_contracts_manager_status 
    ON contracts(manager_id, status) 
    INCLUDE (annual_value_usd);

-- Table statistics for query planner
ANALYZE customers;
ANALYZE contracts;
ANALYZE contract_events;
ANALYZE spend_history;
ANALYZE support_tickets;
ANALYZE renewal_risks;
ANALYZE providers;
ANALYZE account_managers;
ANALYZE document_metadata;
