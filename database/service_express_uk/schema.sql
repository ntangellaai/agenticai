-- ============================================================
-- Contract Data — PostgreSQL Schema
-- Service Express UK Cloud — Anonymised Summary Data
-- ============================================================
-- 
-- Schema overview:
--   extract_months     — reference table of loaded monthly extracts
--   customers          — one row per customer (stable reference)
--   contracts          — one snapshot per contract per month
--   contract_services  — deduplicated services per contract per month
--
-- All monetary values are stored as NUMERIC(12,2) representing
-- monthly figures in GBP. No currency symbols are stored.
-- ============================================================


-- ─── Extensions ──────────────────────────────────────────────────────────────

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ─── Extract months ───────────────────────────────────────────────────────────
-- Tracks which monthly extracts have been loaded.
-- Prevents duplicate loads and provides a reference for querying by period.

CREATE TABLE extract_months (
    id               SERIAL PRIMARY KEY,
    extract_month    CHAR(7)      NOT NULL UNIQUE,  -- YYYY-MM format e.g. 2025-04
    month_label      VARCHAR(20)  NOT NULL,          -- Human label e.g. April 2025
    loaded_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    record_count     INTEGER,                        -- Number of contracts loaded
    notes            TEXT                            -- Optional load notes
);

COMMENT ON TABLE extract_months IS 'Reference table tracking monthly data extracts that have been loaded into the database.';
COMMENT ON COLUMN extract_months.extract_month IS 'Month identifier in YYYY-MM format. Unique — prevents duplicate loads.';
COMMENT ON COLUMN extract_months.month_label IS 'Human readable month label e.g. April 2025.';


-- ─── Customers ────────────────────────────────────────────────────────────────
-- One row per customer. Stable reference data that does not change monthly.
-- Segment and account manager live here as they are customer-level attributes.

CREATE TABLE customers (
    id                  SERIAL PRIMARY KEY,
    customer_id         VARCHAR(50)   NOT NULL UNIQUE,  -- Source system customer ID e.g. 115171
    display_name        VARCHAR(200)  NOT NULL,          -- Anonymised company name e.g. Stark Industries
    segment             VARCHAR(100),                    -- D&B market segment e.g. Manufacturing
    sub_segment         VARCHAR(100),                    -- D&B sub-segment e.g. Aerospace & Defence
    account_manager     VARCHAR(200),                    -- Anonymised account manager name (GoT character)
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE customers IS 'One row per customer. Customer ID is the source system reference. Display name is the anonymised fictional company name.';
COMMENT ON COLUMN customers.customer_id IS 'Source system customer ID — stable identifier across all monthly extracts.';
COMMENT ON COLUMN customers.display_name IS 'Anonymised fictional company name assigned at conversion time.';
COMMENT ON COLUMN customers.segment IS 'D&B market segment. Updated when the anonymisation map is refreshed.';
COMMENT ON COLUMN customers.account_manager IS 'Anonymised account manager name using Game of Thrones character names.';

CREATE INDEX idx_customers_customer_id  ON customers (customer_id);
CREATE INDEX idx_customers_segment      ON customers (segment);
CREATE INDEX idx_customers_display_name ON customers (display_name);


-- ─── Contracts ────────────────────────────────────────────────────────────────
-- One row per contract per monthly extract.
-- Full history is preserved — the same contract will have one row per month
-- it appears in an extract, allowing trend analysis over time.

CREATE TABLE contracts (
    id                      SERIAL PRIMARY KEY,
    extract_month_id        INTEGER       NOT NULL REFERENCES extract_months (id),
    customer_id             INTEGER       NOT NULL REFERENCES customers (id),
    contract_number         VARCHAR(50)   NOT NULL,  -- Anonymised e.g. DEMO-0354
    line_of_business        VARCHAR(100)  NOT NULL,
    contract_end            DATE,                    -- Contract end / renewal date
    contract_length_months  INTEGER,                 -- Term in months e.g. 12, 24, 36, 60
    contract_length_label   VARCHAR(50),             -- Human label e.g. 36 months (3 years)
    invoice_frequency_months INTEGER,                -- Invoice frequency in months e.g. 12 = annual
    contract_total_monthly  NUMERIC(12,2) NOT NULL,  -- Total monthly value after discount
    discount_applied        BOOLEAN       NOT NULL DEFAULT FALSE,
    discount_pct            NUMERIC(5,2)  NOT NULL DEFAULT 0.00,
    created_at              TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE contracts IS 'Monthly snapshot of each contract. One row per contract per extract month — full history preserved for trend analysis.';
COMMENT ON COLUMN contracts.contract_number IS 'Anonymised contract reference in DEMO-NNNN format.';
COMMENT ON COLUMN contracts.contract_end IS 'Contract end date. Use this for renewal pipeline queries.';
COMMENT ON COLUMN contracts.contract_total_monthly IS 'Total monthly value of the contract after discount has been applied. Sum of all service line items.';
COMMENT ON COLUMN contracts.discount_pct IS 'Discount percentage applied to this contract. 0.00 means no discount.';

CREATE INDEX idx_contracts_extract_month  ON contracts (extract_month_id);
CREATE INDEX idx_contracts_customer       ON contracts (customer_id);
CREATE INDEX idx_contracts_number         ON contracts (contract_number);
CREATE INDEX idx_contracts_end_date       ON contracts (contract_end);
CREATE INDEX idx_contracts_discount       ON contracts (discount_applied);
CREATE UNIQUE INDEX idx_contracts_unique  ON contracts (extract_month_id, contract_number);


-- ─── Contract services ────────────────────────────────────────────────────────
-- One row per service per contract per monthly extract.
-- Services are deduplicated by service name — multiple SIS code line items
-- for the same service are combined into a single row with quantity and total.

CREATE TABLE contract_services (
    id                  SERIAL PRIMARY KEY,
    contract_id         INTEGER       NOT NULL REFERENCES contracts (id) ON DELETE CASCADE,
    service_name        VARCHAR(200)  NOT NULL,  -- e.g. Managed Backup, IBM Power IaaS
    service_line        VARCHAR(200),             -- e.g. Managed Backup and Recovery
    quantity            INTEGER       NOT NULL DEFAULT 1,  -- Number of SIS code line items for this service
    monthly_total       NUMERIC(12,2) NOT NULL,  -- Total monthly price paid for this service after discount
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE contract_services IS 'Deduplicated service lines per contract per month. Multiple SIS code rows for the same service are combined — quantity reflects the count of individual line items.';
COMMENT ON COLUMN contract_services.service_name IS 'Human readable service name e.g. Managed Backup, IBM Power IaaS.';
COMMENT ON COLUMN contract_services.service_line IS 'Portfolio service line grouping e.g. Managed Backup and Recovery, Infrastructure as a Service.';
COMMENT ON COLUMN contract_services.quantity IS 'Number of individual SIS code line items that were combined into this service entry.';
COMMENT ON COLUMN contract_services.monthly_total IS 'Total monthly price paid for all line items of this service on this contract after discount.';

CREATE INDEX idx_contract_services_contract  ON contract_services (contract_id);
CREATE INDEX idx_contract_services_name      ON contract_services (service_name);
CREATE INDEX idx_contract_services_line      ON contract_services (service_line);


-- ─── Useful views ─────────────────────────────────────────────────────────────
-- Pre-built views for common query patterns.

-- Full contract summary — joins all tables into one flat view
CREATE VIEW v_contract_summary AS
SELECT
    em.extract_month,
    em.month_label,
    c.display_name                          AS customer_name,
    c.customer_id                           AS customer_ref,
    c.segment,
    c.sub_segment,
    c.account_manager,
    co.contract_number,
    co.line_of_business,
    co.contract_end,
    co.contract_length_months,
    co.contract_length_label,
    co.invoice_frequency_months,
    co.contract_total_monthly,
    co.discount_applied,
    co.discount_pct
FROM contracts co
JOIN customers      c  ON c.id  = co.customer_id
JOIN extract_months em ON em.id = co.extract_month_id;

COMMENT ON VIEW v_contract_summary IS 'Flat view of all contracts with customer and extract month details. Use for contract-level queries and trend analysis.';


-- Service breakdown — all services across all contracts with customer context
CREATE VIEW v_service_breakdown AS
SELECT
    em.extract_month,
    em.month_label,
    c.display_name                          AS customer_name,
    c.segment,
    c.account_manager,
    co.contract_number,
    co.contract_end,
    co.discount_pct,
    cs.service_name,
    cs.service_line,
    cs.quantity,
    cs.monthly_total
FROM contract_services cs
JOIN contracts      co ON co.id  = cs.contract_id
JOIN customers      c  ON c.id   = co.customer_id
JOIN extract_months em ON em.id  = co.extract_month_id;

COMMENT ON VIEW v_service_breakdown IS 'Flat view of all service lines across all contracts with customer and month context. Use for service-level queries and portfolio analysis.';


-- Customer portfolio — latest month only, total value per customer
CREATE VIEW v_customer_portfolio_latest AS
SELECT
    c.display_name                          AS customer_name,
    c.segment,
    c.account_manager,
    COUNT(DISTINCT co.contract_number)      AS contract_count,
    SUM(co.contract_total_monthly)          AS total_monthly_value,
    MIN(co.contract_end)                    AS earliest_renewal,
    MAX(co.contract_end)                    AS latest_renewal
FROM contracts co
JOIN customers      c  ON c.id  = co.customer_id
JOIN extract_months em ON em.id = co.extract_month_id
WHERE em.extract_month = (SELECT MAX(extract_month) FROM extract_months)
GROUP BY c.display_name, c.segment, c.account_manager
ORDER BY total_monthly_value DESC;

COMMENT ON VIEW v_customer_portfolio_latest IS 'Customer portfolio summary for the most recent extract month only. Shows total monthly value, contract count and renewal dates per customer.';


-- Renewal pipeline — contracts ending in next 90 days (latest extract)
CREATE VIEW v_renewal_pipeline AS
SELECT
    c.display_name                          AS customer_name,
    c.segment,
    c.account_manager,
    co.contract_number,
    co.contract_end,
    co.contract_end - CURRENT_DATE          AS days_to_renewal,
    co.contract_total_monthly,
    co.discount_pct,
    STRING_AGG(cs.service_name, ', ' ORDER BY cs.service_name) AS services
FROM contracts co
JOIN customers         c  ON c.id  = co.customer_id
JOIN extract_months    em ON em.id = co.extract_month_id
JOIN contract_services cs ON cs.contract_id = co.id
WHERE em.extract_month = (SELECT MAX(extract_month) FROM extract_months)
  AND co.contract_end BETWEEN CURRENT_DATE AND CURRENT_DATE + INTERVAL '90 days'
GROUP BY
    c.display_name, c.segment, c.account_manager,
    co.contract_number, co.contract_end, co.contract_total_monthly, co.discount_pct
ORDER BY co.contract_end;

COMMENT ON VIEW v_renewal_pipeline IS 'Contracts due for renewal within the next 90 days based on the most recent extract. Update the interval to change the lookahead window.';