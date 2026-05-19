-- =============================================================================
-- Synthetic Demo Data - Enterprise Contracts
-- Consistent, realistic data for Agentic AI demo
-- =============================================================================

-- =============================================================================
-- ACCOUNT MANAGERS
-- =============================================================================

INSERT INTO account_managers (manager_name, email, region, team, hire_date) VALUES
('Sarah Mitchell',    'sarah.mitchell@company.com',    'North America', 'Enterprise Sales',   '2019-03-15'),
('James Rodriguez',   'james.rodriguez@company.com',   'North America', 'Mid-Market Sales',   '2020-07-01'),
('Emma Thompson',     'emma.thompson@company.com',     'EMEA',          'Enterprise Sales',   '2018-11-20'),
('David Chen',        'david.chen@company.com',        'APAC',          'Enterprise Sales',   '2021-01-10'),
('Rachel Foster',     'rachel.foster@company.com',     'North America', 'Public Sector',      '2019-09-01'),
('Marcus Williams',   'marcus.williams@company.com',   'EMEA',          'Mid-Market Sales',   '2020-04-15'),
('Priya Sharma',      'priya.sharma@company.com',      'APAC',          'Mid-Market Sales',   '2021-06-01'),
('Thomas Baker',      'thomas.baker@company.com',      'North America', 'Enterprise Sales',   '2017-02-28');

-- =============================================================================
-- PROVIDERS
-- =============================================================================

INSERT INTO providers (provider_name, provider_type, tier, country) VALUES
('CloudScale Technologies',   'Infrastructure', 'Strategic',     'United States'),
('DataVault Systems',         'Software',       'Strategic',     'United States'),
('Meridian Consulting',       'Consulting',     'Preferred',     'United Kingdom'),
('NexGen Infrastructure',     'Infrastructure', 'Preferred',     'Germany'),
('Quantum Services Group',    'Services',       'Strategic',     'United States'),
('Pacific Digital Solutions',  'Software',       'Standard',      'Japan'),
('Atlas Hardware Corp',        'Hardware',       'Preferred',     'United States'),
('Nordic Cloud Partners',      'Infrastructure', 'Standard',      'Sweden'),
('Pinnacle Support Services',  'Services',       'Transactional', 'India'),
('Sterling Software Labs',    'Software',       'Preferred',     'Canada');

-- =============================================================================
-- CUSTOMERS
-- =============================================================================

INSERT INTO customers (customer_name, segment, industry, region, annual_revenue_usd, employee_count, onboarded_date, status) VALUES
('Meridian Financial Group',     'Enterprise',     'Financial Services',  'North America', 4500000000.00, 12000, '2020-01-15', 'Active'),
('TechVantage Corporation',      'Enterprise',     'Technology',          'North America', 2800000000.00, 8500,  '2019-06-01', 'Active'),
('Nordic Health Systems',        'Healthcare',     'Healthcare',          'EMEA',          1200000000.00, 5200,  '2021-03-10', 'Active'),
('Pacific Manufacturing Ltd',    'Enterprise',     'Manufacturing',       'APAC',          3100000000.00, 15000, '2020-08-20', 'Active'),
('Summit Energy Partners',       'Enterprise',     'Energy',              'North America', 6200000000.00, 22000, '2018-11-01', 'Active'),
('Lighthouse Education Trust',   'Public Sector',  'Education',           'EMEA',          450000000.00,  3200,  '2021-09-15', 'Active'),
('Velocity Logistics Inc',       'Mid-Market',     'Logistics',           'North America', 890000000.00,  4100,  '2022-01-20', 'Active'),
('CrestWave Media Group',        'Mid-Market',     'Media',               'North America', 620000000.00,  2800,  '2021-05-01', 'At Risk'),
('Pinnacle Retail Holdings',     'Enterprise',     'Retail',              'EMEA',          5100000000.00, 35000, '2019-02-15', 'Active'),
('Dragon Gate Technologies',     'Mid-Market',     'Technology',          'APAC',          750000000.00,  3400,  '2022-04-01', 'Active'),
('Federal Transit Authority',    'Public Sector',  'Government',          'North America', 0.00,          8900,  '2020-06-15', 'Active'),
('Greenfield Pharmaceuticals',   'Healthcare',     'Pharmaceuticals',     'North America', 2100000000.00, 6800,  '2019-10-01', 'Active'),
('Sapphire Insurance Group',     'Enterprise',     'Insurance',           'EMEA',          3400000000.00, 11000, '2020-04-01', 'Active'),
('Horizon Aerospace',            'Enterprise',     'Aerospace',           'North America', 7800000000.00, 28000, '2018-07-15', 'Active'),
('BrightPath SMB Solutions',     'SMB',            'Technology',          'North America', 45000000.00,   120,   '2023-01-10', 'Active'),
('Coastal Healthcare Network',   'Healthcare',     'Healthcare',          'North America', 980000000.00,  4500,  '2021-11-01', 'Active'),
('Atlas Mining Corporation',     'Enterprise',     'Mining',              'APAC',          4200000000.00, 18000, '2019-05-20', 'Active'),
('Evergreen Retail Co',          'Mid-Market',     'Retail',              'EMEA',          520000000.00,  2200,  '2022-07-01', 'At Risk'),
('Quantum Research Institute',   'Public Sector',  'Research',            'EMEA',          280000000.00,  1500,  '2021-02-01', 'Active'),
('Sterling Financial Services',  'Enterprise',     'Financial Services',  'North America', 2900000000.00, 9200,  '2020-09-15', 'Active');

-- =============================================================================
-- CONTRACTS
-- =============================================================================

INSERT INTO contracts (contract_ref, customer_id, provider_id, manager_id, contract_type, start_date, end_date, annual_value_usd, total_contract_value, status, auto_renew, payment_terms) VALUES
-- Meridian Financial Group
('CTR-2021-001', 1, 1, 1, 'Infrastructure', '2021-01-01', '2024-12-31', 850000.00, 3400000.00, 'Active', TRUE, 'Net 30'),
('CTR-2021-002', 1, 2, 1, 'Software',       '2021-03-01', '2025-02-28', 420000.00, 1680000.00, 'Active', TRUE, 'Net 30'),
('CTR-2023-015', 1, 5, 1, 'Services',       '2023-06-01', '2025-05-31', 280000.00, 560000.00,  'Active', FALSE, 'Net 45'),

-- TechVantage Corporation
('CTR-2020-003', 2, 1, 8, 'Infrastructure', '2020-04-01', '2025-03-31', 1200000.00, 6000000.00, 'Active', TRUE, 'Net 30'),
('CTR-2022-010', 2, 10, 8, 'Software',      '2022-01-01', '2024-12-31', 350000.00, 1050000.00, 'Pending Renewal', FALSE, 'Net 30'),

-- Nordic Health Systems
('CTR-2021-004', 3, 4, 3, 'Infrastructure', '2021-07-01', '2024-06-30', 520000.00, 1560000.00, 'Pending Renewal', FALSE, 'Net 60'),
('CTR-2022-011', 3, 9, 3, 'Support',        '2022-01-01', '2025-12-31', 180000.00, 720000.00,  'Active', TRUE, 'Net 30'),

-- Pacific Manufacturing Ltd
('CTR-2021-005', 4, 1, 4, 'Infrastructure', '2021-01-01', '2025-12-31', 980000.00, 4900000.00, 'Active', TRUE, 'Net 30'),
('CTR-2022-012', 4, 6, 4, 'Software',       '2022-04-01', '2025-03-31', 290000.00, 870000.00,  'Active', FALSE, 'Net 45'),
('CTR-2023-016', 4, 5, 4, 'Services',       '2023-01-01', '2024-12-31', 450000.00, 900000.00,  'Pending Renewal', FALSE, 'Net 30'),

-- Summit Energy Partners
('CTR-2019-006', 5, 1, 8, 'Infrastructure', '2019-01-01', '2025-12-31', 2100000.00, 14700000.00, 'Active', TRUE, 'Net 30'),
('CTR-2020-007', 5, 2, 8, 'Software',       '2020-06-01', '2025-05-31', 680000.00, 3400000.00, 'Active', TRUE, 'Net 30'),
('CTR-2022-013', 5, 3, 8, 'Consulting',     '2022-09-01', '2024-08-31', 520000.00, 1040000.00, 'Expired', FALSE, 'Net 45'),

-- Lighthouse Education Trust
('CTR-2022-008', 6, 8, 3, 'Infrastructure', '2022-01-01', '2024-12-31', 185000.00, 555000.00, 'Active', FALSE, 'Net 60'),
('CTR-2023-017', 6, 9, 3, 'Support',        '2023-03-01', '2025-02-28', 95000.00,  190000.00, 'Active', TRUE, 'Net 30'),

-- Velocity Logistics Inc
('CTR-2022-009', 7, 1, 2, 'Infrastructure', '2022-03-01', '2025-02-28', 380000.00, 1140000.00, 'Active', TRUE, 'Net 30'),
('CTR-2023-018', 7, 10, 2, 'Software',      '2023-01-01', '2025-12-31', 220000.00, 660000.00, 'Active', FALSE, 'Net 30'),

-- CrestWave Media Group (At Risk)
('CTR-2021-019', 8, 4, 2, 'Infrastructure', '2021-06-01', '2024-05-31', 310000.00, 930000.00, 'Pending Renewal', FALSE, 'Net 30'),
('CTR-2022-020', 8, 9, 2, 'Support',        '2022-07-01', '2024-06-30', 120000.00, 240000.00, 'Expired', FALSE, 'Net 30'),

-- Pinnacle Retail Holdings
('CTR-2019-021', 9, 1, 3, 'Infrastructure', '2019-06-01', '2025-05-31', 1450000.00, 8700000.00, 'Active', TRUE, 'Net 30'),
('CTR-2021-022', 9, 2, 3, 'Software',       '2021-01-01', '2025-12-31', 580000.00, 2900000.00, 'Active', TRUE, 'Net 45'),
('CTR-2023-023', 9, 3, 3, 'Consulting',     '2023-04-01', '2025-03-31', 340000.00, 680000.00, 'Active', FALSE, 'Net 60'),

-- Dragon Gate Technologies
('CTR-2022-024', 10, 6, 7, 'Software',      '2022-07-01', '2025-06-30', 260000.00, 780000.00, 'Active', FALSE, 'Net 30'),
('CTR-2023-025', 10, 1, 7, 'Infrastructure', '2023-01-01', '2025-12-31', 410000.00, 1230000.00, 'Active', TRUE, 'Net 30'),

-- Federal Transit Authority
('CTR-2020-026', 11, 7, 5, 'Hardware',      '2020-10-01', '2025-09-30', 890000.00, 4450000.00, 'Active', FALSE, 'Net 60'),
('CTR-2022-027', 11, 5, 5, 'Services',      '2022-01-01', '2024-12-31', 650000.00, 1950000.00, 'Pending Renewal', FALSE, 'Net 60'),

-- Greenfield Pharmaceuticals
('CTR-2020-028', 12, 2, 1, 'Software',      '2020-01-01', '2025-12-31', 720000.00, 4320000.00, 'Active', TRUE, 'Net 30'),
('CTR-2021-029', 12, 1, 1, 'Infrastructure', '2021-06-01', '2025-05-31', 950000.00, 3800000.00, 'Active', TRUE, 'Net 30'),

-- Sapphire Insurance Group
('CTR-2020-030', 13, 1, 3, 'Infrastructure', '2020-07-01', '2025-06-30', 1100000.00, 5500000.00, 'Active', TRUE, 'Net 30'),
('CTR-2021-031', 13, 2, 3, 'Software',       '2021-04-01', '2025-03-31', 480000.00, 1920000.00, 'Active', TRUE, 'Net 30'),
('CTR-2023-032', 13, 3, 3, 'Consulting',     '2023-01-01', '2024-12-31', 290000.00, 580000.00, 'Pending Renewal', FALSE, 'Net 45'),

-- Horizon Aerospace
('CTR-2019-033', 14, 1, 8, 'Infrastructure', '2019-01-01', '2025-12-31', 2800000.00, 19600000.00, 'Active', TRUE, 'Net 30'),
('CTR-2020-034', 14, 7, 8, 'Hardware',       '2020-03-01', '2025-02-28', 1500000.00, 7500000.00, 'Active', TRUE, 'Net 45'),
('CTR-2022-035', 14, 5, 8, 'Services',       '2022-06-01', '2025-05-31', 890000.00, 2670000.00, 'Active', FALSE, 'Net 30'),

-- BrightPath SMB Solutions
('CTR-2023-036', 15, 8, 2, 'Infrastructure', '2023-04-01', '2025-03-31', 48000.00, 96000.00, 'Active', TRUE, 'Net 30'),
('CTR-2023-037', 15, 10, 2, 'Software',      '2023-06-01', '2025-05-31', 24000.00, 48000.00, 'Active', FALSE, 'Net 30'),

-- Coastal Healthcare Network
('CTR-2022-038', 16, 2, 1, 'Software',       '2022-01-01', '2025-12-31', 390000.00, 1560000.00, 'Active', TRUE, 'Net 30'),
('CTR-2022-039', 16, 1, 1, 'Infrastructure', '2022-04-01', '2025-03-31', 620000.00, 1860000.00, 'Active', TRUE, 'Net 30'),

-- Atlas Mining Corporation
('CTR-2020-040', 17, 1, 4, 'Infrastructure', '2020-01-01', '2025-12-31', 1650000.00, 9900000.00, 'Active', TRUE, 'Net 30'),
('CTR-2021-041', 17, 7, 4, 'Hardware',       '2021-03-01', '2024-02-28', 980000.00, 2940000.00, 'Renewed', FALSE, 'Net 45'),
('CTR-2024-042', 17, 7, 4, 'Hardware',       '2024-03-01', '2027-02-28', 1150000.00, 3450000.00, 'Active', FALSE, 'Net 45'),

-- Evergreen Retail Co (At Risk)
('CTR-2022-043', 18, 4, 6, 'Infrastructure', '2022-09-01', '2024-08-31', 195000.00, 390000.00, 'Pending Renewal', FALSE, 'Net 30'),
('CTR-2023-044', 18, 9, 6, 'Support',        '2023-01-01', '2024-12-31', 85000.00, 170000.00, 'Active', FALSE, 'Net 30'),

-- Quantum Research Institute
('CTR-2021-045', 19, 8, 6, 'Infrastructure', '2021-04-01', '2025-03-31', 210000.00, 840000.00, 'Active', TRUE, 'Net 60'),
('CTR-2023-046', 19, 6, 6, 'Software',       '2023-07-01', '2025-06-30', 145000.00, 290000.00, 'Active', FALSE, 'Net 60'),

-- Sterling Financial Services
('CTR-2021-047', 20, 1, 1, 'Infrastructure', '2021-01-01', '2025-12-31', 1050000.00, 5250000.00, 'Active', TRUE, 'Net 30'),
('CTR-2021-048', 20, 2, 1, 'Software',       '2021-06-01', '2025-05-31', 560000.00, 2240000.00, 'Active', TRUE, 'Net 30'),
('CTR-2023-049', 20, 5, 1, 'Services',       '2023-03-01', '2025-02-28', 320000.00, 640000.00, 'Active', FALSE, 'Net 45');

-- =============================================================================
-- CONTRACT EVENTS
-- =============================================================================

INSERT INTO contract_events (contract_id, event_type, event_date, description, old_value_usd, new_value_usd, changed_by) VALUES
-- Meridian Financial - expansion
(1, 'Created', '2021-01-01', 'Initial infrastructure contract signed', NULL, 850000.00, 'Sarah Mitchell'),
(1, 'Expanded', '2022-06-15', 'Added disaster recovery services and additional compute capacity', 650000.00, 850000.00, 'Sarah Mitchell'),
(2, 'Created', '2021-03-01', 'Enterprise software license agreement', NULL, 420000.00, 'Sarah Mitchell'),
(2, 'Price Increase', '2023-03-01', 'Annual price escalation per contract terms (5%)', 400000.00, 420000.00, 'Sarah Mitchell'),

-- TechVantage - large infrastructure deal
(4, 'Created', '2020-04-01', 'Multi-year infrastructure modernisation contract', NULL, 900000.00, 'Thomas Baker'),
(4, 'Expanded', '2022-01-01', 'Scope expansion to include AI/ML infrastructure workloads', 900000.00, 1200000.00, 'Thomas Baker'),
(5, 'Created', '2022-01-01', 'Development platform license', NULL, 350000.00, 'Thomas Baker'),

-- Summit Energy - major account
(11, 'Created', '2019-01-01', 'Enterprise infrastructure agreement - 7 year term', NULL, 1800000.00, 'Thomas Baker'),
(11, 'Expanded', '2021-01-01', 'Added edge computing and IoT platform support', 1800000.00, 2100000.00, 'Thomas Baker'),
(11, 'Price Increase', '2023-01-01', 'Contractual CPI adjustment', 2000000.00, 2100000.00, 'Thomas Baker'),
(12, 'Created', '2020-06-01', 'Analytics and data platform software', NULL, 580000.00, 'Thomas Baker'),
(12, 'Expanded', '2022-06-01', 'Added advanced analytics modules', 580000.00, 680000.00, 'Thomas Baker'),

-- CrestWave Media - declining (at risk)
(18, 'Created', '2021-06-01', 'Cloud infrastructure for media streaming', NULL, 410000.00, 'James Rodriguez'),
(18, 'Reduced', '2023-01-01', 'Customer downsized streaming operations, reduced capacity', 410000.00, 310000.00, 'James Rodriguez'),
(19, 'Created', '2022-07-01', 'Technical support agreement', NULL, 120000.00, 'James Rodriguez'),
(19, 'Escalation', '2023-09-15', 'Multiple SLA breaches reported, customer escalated to VP level', NULL, NULL, 'James Rodriguez'),

-- Horizon Aerospace - premium account
(31, 'Created', '2019-01-01', 'Enterprise-wide infrastructure contract - strategic partnership', NULL, 2400000.00, 'Thomas Baker'),
(31, 'Expanded', '2021-07-01', 'Added secure cloud workloads for defence projects', 2400000.00, 2800000.00, 'Thomas Baker'),
(32, 'Created', '2020-03-01', 'Specialised hardware for simulation workloads', NULL, 1200000.00, 'Thomas Baker'),
(32, 'Price Increase', '2022-03-01', 'Hardware refresh cycle - newer generation equipment', 1200000.00, 1500000.00, 'Thomas Baker'),

-- Atlas Mining - hardware renewal
(37, 'Created', '2021-03-01', 'Mining operations hardware - ruggedised systems', NULL, 980000.00, 'David Chen'),
(37, 'Renewed', '2024-03-01', 'Hardware refresh and renewal at higher spec', 980000.00, 1150000.00, 'David Chen'),

-- Pinnacle Retail - steady growth
(20, 'Created', '2019-06-01', 'Global retail infrastructure platform', NULL, 1200000.00, 'Emma Thompson'),
(20, 'Expanded', '2021-01-01', 'Added e-commerce platform infrastructure', 1200000.00, 1350000.00, 'Emma Thompson'),
(20, 'Expanded', '2023-01-01', 'Added AI-powered inventory management infrastructure', 1350000.00, 1450000.00, 'Emma Thompson'),

-- Evergreen Retail - at risk
(40, 'Created', '2022-09-01', 'Basic cloud infrastructure', NULL, 195000.00, 'Marcus Williams'),
(40, 'Escalation', '2024-02-15', 'Customer reported dissatisfaction with response times', NULL, NULL, 'Marcus Williams');

-- =============================================================================
-- SPEND HISTORY (Quarterly)
-- =============================================================================

-- Meridian Financial Group - steady growth
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count) VALUES
(1, 1, 2022, 1, 162500.00, 'Infrastructure', 3), (1, 1, 2022, 2, 165000.00, 'Infrastructure', 3),
(1, 1, 2022, 3, 212500.00, 'Infrastructure', 3), (1, 1, 2022, 4, 215000.00, 'Infrastructure', 3),
(1, 1, 2023, 1, 212500.00, 'Infrastructure', 3), (1, 1, 2023, 2, 212500.00, 'Infrastructure', 3),
(1, 1, 2023, 3, 215000.00, 'Infrastructure', 3), (1, 1, 2023, 4, 212500.00, 'Infrastructure', 3),
(1, 1, 2024, 1, 215000.00, 'Infrastructure', 3), (1, 1, 2024, 2, 212500.00, 'Infrastructure', 3),
(1, 1, 2024, 3, 218000.00, 'Infrastructure', 3), (1, 1, 2024, 4, 220000.00, 'Infrastructure', 3),
(1, 2, 2022, 1, 100000.00, 'Software', 1), (1, 2, 2022, 2, 100000.00, 'Software', 1),
(1, 2, 2022, 3, 100000.00, 'Software', 1), (1, 2, 2022, 4, 100000.00, 'Software', 1),
(1, 2, 2023, 1, 105000.00, 'Software', 1), (1, 2, 2023, 2, 105000.00, 'Software', 1),
(1, 2, 2023, 3, 105000.00, 'Software', 1), (1, 2, 2023, 4, 105000.00, 'Software', 1),
(1, 2, 2024, 1, 105000.00, 'Software', 1), (1, 2, 2024, 2, 105000.00, 'Software', 1),
(1, 2, 2024, 3, 105000.00, 'Software', 1), (1, 2, 2024, 4, 105000.00, 'Software', 1);

-- TechVantage Corporation - expanded in 2022
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count) VALUES
(2, 4, 2022, 1, 225000.00, 'Infrastructure', 3), (2, 4, 2022, 2, 300000.00, 'Infrastructure', 3),
(2, 4, 2022, 3, 300000.00, 'Infrastructure', 3), (2, 4, 2022, 4, 300000.00, 'Infrastructure', 3),
(2, 4, 2023, 1, 300000.00, 'Infrastructure', 3), (2, 4, 2023, 2, 300000.00, 'Infrastructure', 3),
(2, 4, 2023, 3, 305000.00, 'Infrastructure', 3), (2, 4, 2023, 4, 300000.00, 'Infrastructure', 3),
(2, 4, 2024, 1, 300000.00, 'Infrastructure', 3), (2, 4, 2024, 2, 305000.00, 'Infrastructure', 3),
(2, 4, 2024, 3, 300000.00, 'Infrastructure', 3), (2, 4, 2024, 4, 300000.00, 'Infrastructure', 3),
(2, 5, 2022, 1, 87500.00, 'Software', 1), (2, 5, 2022, 2, 87500.00, 'Software', 1),
(2, 5, 2022, 3, 87500.00, 'Software', 1), (2, 5, 2022, 4, 87500.00, 'Software', 1),
(2, 5, 2023, 1, 87500.00, 'Software', 1), (2, 5, 2023, 2, 87500.00, 'Software', 1),
(2, 5, 2023, 3, 87500.00, 'Software', 1), (2, 5, 2023, 4, 87500.00, 'Software', 1),
(2, 5, 2024, 1, 87500.00, 'Software', 1), (2, 5, 2024, 2, 87500.00, 'Software', 1),
(2, 5, 2024, 3, 87500.00, 'Software', 1), (2, 5, 2024, 4, 87500.00, 'Software', 1);

-- CrestWave Media - declining spend
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count) VALUES
(8, 18, 2022, 1, 102500.00, 'Infrastructure', 2), (8, 18, 2022, 2, 102500.00, 'Infrastructure', 2),
(8, 18, 2022, 3, 102500.00, 'Infrastructure', 2), (8, 18, 2022, 4, 102500.00, 'Infrastructure', 2),
(8, 18, 2023, 1, 77500.00, 'Infrastructure', 2), (8, 18, 2023, 2, 77500.00, 'Infrastructure', 2),
(8, 18, 2023, 3, 77500.00, 'Infrastructure', 2), (8, 18, 2023, 4, 77500.00, 'Infrastructure', 2),
(8, 18, 2024, 1, 77500.00, 'Infrastructure', 2), (8, 18, 2024, 2, 77500.00, 'Infrastructure', 2),
(8, 19, 2022, 3, 30000.00, 'Support', 1), (8, 19, 2022, 4, 30000.00, 'Support', 1),
(8, 19, 2023, 1, 30000.00, 'Support', 1), (8, 19, 2023, 2, 30000.00, 'Support', 1),
(8, 19, 2023, 3, 30000.00, 'Support', 1), (8, 19, 2023, 4, 30000.00, 'Support', 1),
(8, 19, 2024, 1, 30000.00, 'Support', 1), (8, 19, 2024, 2, 30000.00, 'Support', 1);

-- Summit Energy Partners - large spender
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count) VALUES
(5, 11, 2022, 1, 500000.00, 'Infrastructure', 5), (5, 11, 2022, 2, 500000.00, 'Infrastructure', 5),
(5, 11, 2022, 3, 525000.00, 'Infrastructure', 5), (5, 11, 2022, 4, 525000.00, 'Infrastructure', 5),
(5, 11, 2023, 1, 525000.00, 'Infrastructure', 5), (5, 11, 2023, 2, 525000.00, 'Infrastructure', 5),
(5, 11, 2023, 3, 530000.00, 'Infrastructure', 5), (5, 11, 2023, 4, 525000.00, 'Infrastructure', 5),
(5, 11, 2024, 1, 525000.00, 'Infrastructure', 5), (5, 11, 2024, 2, 530000.00, 'Infrastructure', 5),
(5, 11, 2024, 3, 525000.00, 'Infrastructure', 5), (5, 11, 2024, 4, 525000.00, 'Infrastructure', 5),
(5, 12, 2022, 1, 145000.00, 'Software', 1), (5, 12, 2022, 2, 145000.00, 'Software', 1),
(5, 12, 2022, 3, 170000.00, 'Software', 1), (5, 12, 2022, 4, 170000.00, 'Software', 1),
(5, 12, 2023, 1, 170000.00, 'Software', 1), (5, 12, 2023, 2, 170000.00, 'Software', 1),
(5, 12, 2023, 3, 170000.00, 'Software', 1), (5, 12, 2023, 4, 170000.00, 'Software', 1),
(5, 12, 2024, 1, 170000.00, 'Software', 1), (5, 12, 2024, 2, 170000.00, 'Software', 1),
(5, 12, 2024, 3, 170000.00, 'Software', 1), (5, 12, 2024, 4, 170000.00, 'Software', 1);

-- Horizon Aerospace - premium
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count) VALUES
(14, 31, 2022, 1, 600000.00, 'Infrastructure', 6), (14, 31, 2022, 2, 600000.00, 'Infrastructure', 6),
(14, 31, 2022, 3, 700000.00, 'Infrastructure', 6), (14, 31, 2022, 4, 700000.00, 'Infrastructure', 6),
(14, 31, 2023, 1, 700000.00, 'Infrastructure', 6), (14, 31, 2023, 2, 700000.00, 'Infrastructure', 6),
(14, 31, 2023, 3, 700000.00, 'Infrastructure', 6), (14, 31, 2023, 4, 700000.00, 'Infrastructure', 6),
(14, 31, 2024, 1, 700000.00, 'Infrastructure', 6), (14, 31, 2024, 2, 700000.00, 'Infrastructure', 6),
(14, 31, 2024, 3, 700000.00, 'Infrastructure', 6), (14, 31, 2024, 4, 700000.00, 'Infrastructure', 6),
(14, 32, 2022, 1, 300000.00, 'Hardware', 2), (14, 32, 2022, 2, 375000.00, 'Hardware', 2),
(14, 32, 2022, 3, 375000.00, 'Hardware', 2), (14, 32, 2022, 4, 375000.00, 'Hardware', 2),
(14, 32, 2023, 1, 375000.00, 'Hardware', 2), (14, 32, 2023, 2, 375000.00, 'Hardware', 2),
(14, 32, 2023, 3, 375000.00, 'Hardware', 2), (14, 32, 2023, 4, 375000.00, 'Hardware', 2),
(14, 32, 2024, 1, 375000.00, 'Hardware', 2), (14, 32, 2024, 2, 375000.00, 'Hardware', 2),
(14, 32, 2024, 3, 375000.00, 'Hardware', 2), (14, 32, 2024, 4, 375000.00, 'Hardware', 2);

-- Pinnacle Retail Holdings - growth
INSERT INTO spend_history (customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category, invoice_count) VALUES
(9, 20, 2022, 1, 337500.00, 'Infrastructure', 4), (9, 20, 2022, 2, 337500.00, 'Infrastructure', 4),
(9, 20, 2022, 3, 337500.00, 'Infrastructure', 4), (9, 20, 2022, 4, 337500.00, 'Infrastructure', 4),
(9, 20, 2023, 1, 362500.00, 'Infrastructure', 4), (9, 20, 2023, 2, 362500.00, 'Infrastructure', 4),
(9, 20, 2023, 3, 362500.00, 'Infrastructure', 4), (9, 20, 2023, 4, 362500.00, 'Infrastructure', 4),
(9, 20, 2024, 1, 365000.00, 'Infrastructure', 4), (9, 20, 2024, 2, 362500.00, 'Infrastructure', 4),
(9, 20, 2024, 3, 365000.00, 'Infrastructure', 4), (9, 20, 2024, 4, 362500.00, 'Infrastructure', 4);

-- =============================================================================
-- SUPPORT TICKETS
-- =============================================================================

INSERT INTO support_tickets (customer_id, contract_id, severity, category, subject, status, opened_date, resolved_date, resolution_hours) VALUES
-- CrestWave Media - many tickets (contributes to risk)
(8, 18, 'High',     'Performance',    'Streaming latency exceeding SLA thresholds',         'Resolved', '2023-06-15', '2023-06-17', 48.5),
(8, 18, 'Critical', 'Outage',         'Complete service outage affecting production',         'Resolved', '2023-08-22', '2023-08-23', 18.0),
(8, 18, 'High',     'Performance',    'Degraded throughput during peak hours',               'Resolved', '2023-10-05', '2023-10-08', 72.0),
(8, 19, 'Medium',   'Billing',        'Invoice discrepancy for Q3 support charges',          'Resolved', '2023-11-01', '2023-11-05', 96.0),
(8, 18, 'Critical', 'Outage',         'Failover did not trigger during primary DC failure',   'Escalated', '2024-01-15', NULL, NULL),
(8, 18, 'High',     'Performance',    'API response times 3x above baseline',               'Open',     '2024-03-01', NULL, NULL),
(8, 18, 'High',     'Security',       'Vulnerability scan flagged unpatched components',      'In Progress', '2024-03-20', NULL, NULL),

-- Evergreen Retail - service issues
(18, 40, 'High',    'Performance',    'E-commerce platform slow during sale events',          'Resolved', '2023-11-24', '2023-11-27', 72.0),
(18, 40, 'Medium',  'Configuration',  'SSL certificate renewal failed',                       'Resolved', '2024-01-10', '2024-01-11', 24.0),
(18, 40, 'High',    'Outage',         'Checkout service unavailable for 2 hours',             'Resolved', '2024-02-14', '2024-02-14', 6.0),
(18, 41, 'Medium',  'Billing',        'Overcharged for support hours in January',             'Open',     '2024-02-28', NULL, NULL),
(18, 40, 'Critical','Outage',         'Full platform outage during flash sale',               'Escalated', '2024-04-01', NULL, NULL),

-- Meridian Financial - minimal issues (healthy)
(1, 1, 'Low',      'Configuration',  'Request to update DNS records',                        'Closed',   '2023-05-10', '2023-05-10', 2.0),
(1, 1, 'Medium',   'Performance',    'Batch processing slower than expected',                'Closed',   '2023-09-15', '2023-09-16', 18.0),
(1, 2, 'Low',      'Feature Request','Request for additional reporting module',              'Closed',   '2024-01-20', '2024-02-15', 624.0),

-- Summit Energy - occasional critical
(5, 11, 'Critical','Security',       'Suspected unauthorized access attempt detected',       'Resolved', '2023-04-05', '2023-04-05', 4.0),
(5, 11, 'Medium',  'Performance',    'Storage IOPS below contracted SLA for 15 minutes',    'Closed',   '2023-07-22', '2023-07-22', 3.0),
(5, 12, 'Low',     'Feature Request','Request for custom dashboard integration',             'Closed',   '2023-11-01', '2023-12-01', 720.0),
(5, 11, 'High',    'Compliance',     'Audit log gap identified during compliance review',    'Resolved', '2024-02-10', '2024-02-12', 48.0),

-- Nordic Health - compliance focused
(3, 6, 'High',     'Compliance',     'GDPR data residency check required for new region',    'Resolved', '2023-03-15', '2023-03-20', 120.0),
(3, 6, 'Medium',   'Security',       'Certificate rotation request for healthcare systems',  'Closed',   '2023-08-01', '2023-08-02', 16.0),
(3, 7, 'Low',      'Configuration',  'Update monitoring thresholds for night shifts',        'Closed',   '2023-10-10', '2023-10-11', 8.0),

-- Federal Transit Authority
(11, 25, 'Medium', 'Hardware',       'Replacement part needed for terminal device',           'Resolved', '2023-06-01', '2023-06-15', 336.0),
(11, 26, 'High',   'Compliance',     'FedRAMP audit preparation support needed',             'Resolved', '2023-09-01', '2023-09-30', 696.0),
(11, 25, 'Low',    'Configuration',  'Firmware update scheduling for Q1 maintenance',        'Closed',   '2024-01-05', '2024-01-10', 120.0);

-- =============================================================================
-- RENEWAL RISKS
-- =============================================================================

INSERT INTO renewal_risks (contract_id, risk_score, risk_factors, assessed_date, recommended_action, owner_manager_id, status) VALUES
-- CrestWave Media - high risk
(18, 0.85, ARRAY['Multiple SLA breaches', 'Customer escalation to VP', 'Declining spend', 'High support ticket volume', 'No auto-renew'], '2024-03-01', 'Schedule executive business review immediately. Prepare service improvement plan with committed SLAs. Consider credit or discount for retention.', 2, 'Open'),
(19, 0.72, ARRAY['Related to at-risk infrastructure contract', 'Expired without renewal discussion'], '2024-03-01', 'Bundle with infrastructure renewal offer. Proactive outreach required.', 2, 'Open'),

-- Evergreen Retail - medium-high risk
(40, 0.78, ARRAY['Platform outage during critical sale event', 'Multiple escalations', 'No executive relationship', 'Competitor evaluation suspected'], '2024-04-01', 'Immediate executive engagement. Offer proof-of-concept for improved platform. Consider price concession.', 6, 'Open'),

-- Nordic Health Systems - medium risk (compliance)
(6, 0.55, ARRAY['Contract expiring in 60 days', 'No renewal discussion initiated', 'GDPR compliance concern raised', 'No auto-renew'], '2024-04-15', 'Initiate renewal conversation with compliance assurance. Prepare GDPR data residency documentation.', 3, 'Open'),

-- TechVantage - low-medium risk
(5, 0.42, ARRAY['Contract pending renewal', 'Competitor demo scheduled', 'Budget review in progress'], '2024-03-15', 'Proactive pricing discussion. Highlight AI/ML infrastructure capabilities. Demonstrate roadmap.', 8, 'Open'),

-- Sapphire Insurance - consulting expiring
(30, 0.38, ARRAY['Consulting engagement ending', 'No follow-on project identified', 'Stakeholder change at customer'], '2024-03-01', 'Identify new consulting opportunities. Meet new stakeholder. Present outcomes from current engagement.', 3, 'Open'),

-- Federal Transit Authority - services pending
(26, 0.45, ARRAY['Government budget cycle uncertainty', 'Services contract pending renewal', 'Procurement process lengthy'], '2024-03-15', 'Begin procurement paperwork early. Ensure compliance documentation current. Engage government relations.', 5, 'Open');

-- =============================================================================
-- DOCUMENT METADATA
-- =============================================================================

INSERT INTO document_metadata (contract_id, customer_id, document_type, title, summary, storage_path, created_date) VALUES
(1, 1, 'Contract PDF', 'Meridian Financial - Infrastructure MSA', 'Master service agreement for cloud infrastructure services including compute, storage, and networking', '/docs/contracts/CTR-2021-001.pdf', '2021-01-01'),
(18, 8, 'Escalation Report', 'CrestWave Media - VP Escalation Report', 'Summary of service issues, SLA breaches, and customer dissatisfaction leading to VP-level escalation', '/docs/escalations/CW-ESC-2023-001.pdf', '2023-09-20'),
(18, 8, 'Risk Assessment', 'CrestWave Media - Renewal Risk Assessment Q1 2024', 'Detailed risk analysis showing 85% probability of churn without intervention', '/docs/risk/CW-RISK-2024-Q1.pdf', '2024-03-01'),
(11, 5, 'QBR Deck', 'Summit Energy - Q4 2023 Quarterly Business Review', 'Executive summary of service delivery, SLA performance, and strategic roadmap for Summit Energy', '/docs/qbr/SE-QBR-2023-Q4.pdf', '2024-01-15'),
(20, 9, 'Amendment', 'Pinnacle Retail - E-commerce Infrastructure Amendment', 'Contract amendment adding e-commerce platform infrastructure to existing agreement', '/docs/amendments/PR-AMD-2023-001.pdf', '2023-01-01'),
(31, 14, 'Contract PDF', 'Horizon Aerospace - Strategic Partnership Agreement', 'Multi-year strategic partnership for enterprise infrastructure including classified workloads', '/docs/contracts/CTR-2019-033.pdf', '2019-01-01'),
(6, 3, 'Renewal Proposal', 'Nordic Health - Infrastructure Renewal Proposal', 'Proposed renewal terms including GDPR compliance enhancements and expanded disaster recovery', '/docs/proposals/NH-REN-2024-001.pdf', '2024-04-01'),
(40, 18, 'Escalation Report', 'Evergreen Retail - Flash Sale Outage Report', 'Root cause analysis of platform outage during spring flash sale event', '/docs/escalations/ER-ESC-2024-001.pdf', '2024-04-05'),
(4, 2, 'QBR Deck', 'TechVantage - Q1 2024 Quarterly Business Review', 'Review of AI/ML infrastructure utilisation and capacity planning discussion', '/docs/qbr/TV-QBR-2024-Q1.pdf', '2024-04-10'),
(NULL, 1, 'Meeting Notes', 'Meridian Financial - Annual Strategy Session', 'Notes from annual partnership review covering 2024 priorities and growth opportunities', '/docs/meetings/MF-STRAT-2024.pdf', '2024-02-15');
