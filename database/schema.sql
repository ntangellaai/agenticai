-- =============================================================================
-- Enterprise Contracts Database Schema
-- Target: PostgreSQL 16 on OpenShift (ppc64le)
-- Purpose: Agentic AI Demo - Business Intelligence via MCP
-- =============================================================================

-- Create database (run as superuser)
-- CREATE DATABASE enterprise_contracts;
-- \c enterprise_contracts;

-- =============================================================================
-- TABLES
-- =============================================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id         SERIAL PRIMARY KEY,
    customer_name       VARCHAR(200) NOT NULL,
    segment             VARCHAR(50) NOT NULL CHECK (segment IN (
                            'Enterprise', 'Mid-Market', 'SMB', 'Public Sector', 'Healthcare'
                        )),
    industry            VARCHAR(100) NOT NULL,
    region              VARCHAR(50) NOT NULL CHECK (region IN (
                            'North America', 'EMEA', 'APAC', 'LATAM'
                        )),
    annual_revenue_usd  NUMERIC(15,2),
    employee_count      INTEGER,
    onboarded_date      DATE NOT NULL,
    status              VARCHAR(20) NOT NULL DEFAULT 'Active' CHECK (status IN (
                            'Active', 'At Risk', 'Churned', 'Prospect'
                        )),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS account_managers (
    manager_id          SERIAL PRIMARY KEY,
    manager_name        VARCHAR(150) NOT NULL,
    email               VARCHAR(200) NOT NULL UNIQUE,
    region              VARCHAR(50) NOT NULL,
    team                VARCHAR(100),
    hire_date           DATE NOT NULL,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS providers (
    provider_id         SERIAL PRIMARY KEY,
    provider_name       VARCHAR(200) NOT NULL,
    provider_type       VARCHAR(50) NOT NULL CHECK (provider_type IN (
                            'Software', 'Infrastructure', 'Services', 'Consulting', 'Hardware'
                        )),
    tier                VARCHAR(20) NOT NULL CHECK (tier IN (
                            'Strategic', 'Preferred', 'Standard', 'Transactional'
                        )),
    country             VARCHAR(100),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS contracts (
    contract_id         SERIAL PRIMARY KEY,
    contract_ref        VARCHAR(50) NOT NULL UNIQUE,
    customer_id         INTEGER NOT NULL REFERENCES customers(customer_id),
    provider_id         INTEGER NOT NULL REFERENCES providers(provider_id),
    manager_id          INTEGER NOT NULL REFERENCES account_managers(manager_id),
    contract_type       VARCHAR(50) NOT NULL CHECK (contract_type IN (
                            'Subscription', 'License', 'Services', 'Support', 'Managed Service'
                        )),
    start_date          DATE NOT NULL,
    end_date            DATE NOT NULL,
    annual_value_usd    NUMERIC(15,2) NOT NULL,
    total_contract_value NUMERIC(15,2) NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'Active' CHECK (status IN (
                            'Active', 'Expired', 'Renewed', 'Terminated', 'Pending Renewal'
                        )),
    auto_renew          BOOLEAN DEFAULT FALSE,
    payment_terms       VARCHAR(50) DEFAULT 'Net 30',
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_dates CHECK (end_date > start_date)
);

CREATE TABLE IF NOT EXISTS contract_events (
    event_id            SERIAL PRIMARY KEY,
    contract_id         INTEGER NOT NULL REFERENCES contracts(contract_id),
    event_type          VARCHAR(50) NOT NULL CHECK (event_type IN (
                            'Created', 'Renewed', 'Expanded', 'Reduced', 'Terminated',
                            'Price Increase', 'Scope Change', 'Escalation', 'Amendment'
                        )),
    event_date          DATE NOT NULL,
    description         TEXT,
    old_value_usd       NUMERIC(15,2),
    new_value_usd       NUMERIC(15,2),
    changed_by          VARCHAR(150),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS spend_history (
    spend_id            SERIAL PRIMARY KEY,
    customer_id         INTEGER NOT NULL REFERENCES customers(customer_id),
    contract_id         INTEGER REFERENCES contracts(contract_id),
    fiscal_year         INTEGER NOT NULL CHECK (fiscal_year BETWEEN 2018 AND 2030),
    fiscal_quarter      INTEGER NOT NULL CHECK (fiscal_quarter BETWEEN 1 AND 4),
    amount_usd          NUMERIC(15,2) NOT NULL,
    category            VARCHAR(100),
    invoice_count       INTEGER DEFAULT 1,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS support_tickets (
    ticket_id           SERIAL PRIMARY KEY,
    customer_id         INTEGER NOT NULL REFERENCES customers(customer_id),
    contract_id         INTEGER REFERENCES contracts(contract_id),
    severity            VARCHAR(20) NOT NULL CHECK (severity IN (
                            'Critical', 'High', 'Medium', 'Low'
                        )),
    category            VARCHAR(100) NOT NULL,
    subject             VARCHAR(300) NOT NULL,
    status              VARCHAR(30) NOT NULL DEFAULT 'Open' CHECK (status IN (
                            'Open', 'In Progress', 'Resolved', 'Closed', 'Escalated'
                        )),
    opened_date         DATE NOT NULL,
    resolved_date       DATE,
    resolution_hours    NUMERIC(8,2),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS renewal_risks (
    risk_id             SERIAL PRIMARY KEY,
    contract_id         INTEGER NOT NULL REFERENCES contracts(contract_id),
    risk_score          NUMERIC(3,2) NOT NULL CHECK (risk_score BETWEEN 0 AND 1),
    risk_factors        TEXT[],
    assessed_date       DATE NOT NULL,
    recommended_action  TEXT,
    owner_manager_id    INTEGER REFERENCES account_managers(manager_id),
    status              VARCHAR(30) DEFAULT 'Open' CHECK (status IN (
                            'Open', 'Mitigated', 'Lost', 'Renewed'
                        )),
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS document_metadata (
    document_id         SERIAL PRIMARY KEY,
    contract_id         INTEGER REFERENCES contracts(contract_id),
    customer_id         INTEGER REFERENCES customers(customer_id),
    document_type       VARCHAR(50) NOT NULL CHECK (document_type IN (
                            'Contract PDF', 'Amendment', 'Meeting Notes', 'Risk Assessment',
                            'QBR Deck', 'Escalation Report', 'Renewal Proposal'
                        )),
    title               VARCHAR(300) NOT NULL,
    summary             TEXT,
    storage_path        VARCHAR(500),
    created_date        DATE NOT NULL,
    created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================================================
-- INDEXES
-- =============================================================================

CREATE INDEX idx_customers_segment ON customers(segment);
CREATE INDEX idx_customers_region ON customers(region);
CREATE INDEX idx_customers_status ON customers(status);

CREATE INDEX idx_contracts_customer ON contracts(customer_id);
CREATE INDEX idx_contracts_provider ON contracts(provider_id);
CREATE INDEX idx_contracts_manager ON contracts(manager_id);
CREATE INDEX idx_contracts_status ON contracts(status);
CREATE INDEX idx_contracts_end_date ON contracts(end_date);
CREATE INDEX idx_contracts_ref ON contracts(contract_ref);

CREATE INDEX idx_contract_events_contract ON contract_events(contract_id);
CREATE INDEX idx_contract_events_type ON contract_events(event_type);
CREATE INDEX idx_contract_events_date ON contract_events(event_date);

CREATE INDEX idx_spend_customer ON spend_history(customer_id);
CREATE INDEX idx_spend_year_quarter ON spend_history(fiscal_year, fiscal_quarter);
CREATE INDEX idx_spend_contract ON spend_history(contract_id);

CREATE INDEX idx_tickets_customer ON support_tickets(customer_id);
CREATE INDEX idx_tickets_severity ON support_tickets(severity);
CREATE INDEX idx_tickets_status ON support_tickets(status);
CREATE INDEX idx_tickets_opened ON support_tickets(opened_date);

CREATE INDEX idx_renewal_risks_contract ON renewal_risks(contract_id);
CREATE INDEX idx_renewal_risks_score ON renewal_risks(risk_score DESC);

CREATE INDEX idx_documents_contract ON document_metadata(contract_id);
CREATE INDEX idx_documents_customer ON document_metadata(customer_id);
CREATE INDEX idx_documents_type ON document_metadata(document_type);
