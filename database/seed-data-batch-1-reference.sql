-- =============================================================================
-- BATCH 1: Reference Data (Account Managers + Providers)
-- ~30 account managers + ~50 providers
-- Run first — other batches reference these IDs
-- =============================================================================

BEGIN;

-- =============================================================================
-- ACCOUNT MANAGERS (30 records)
-- =============================================================================

INSERT INTO account_managers (manager_name, email, region, team, hire_date) VALUES
('Sarah Mitchell',      'sarah.mitchell@company.com',      'North America', 'Enterprise Sales',   '2019-03-15'),
('James Rodriguez',     'james.rodriguez@company.com',     'North America', 'Mid-Market Sales',   '2020-07-01'),
('Emma Thompson',       'emma.thompson@company.com',       'EMEA',          'Enterprise Sales',   '2018-11-20'),
('David Chen',          'david.chen@company.com',          'APAC',          'Enterprise Sales',   '2021-01-10'),
('Rachel Foster',       'rachel.foster@company.com',       'North America', 'Public Sector',      '2019-09-01'),
('Marcus Williams',     'marcus.williams@company.com',     'EMEA',          'Mid-Market Sales',   '2020-04-15'),
('Priya Sharma',        'priya.sharma@company.com',        'APAC',          'Mid-Market Sales',   '2021-06-01'),
('Thomas Baker',        'thomas.baker@company.com',        'North America', 'Enterprise Sales',   '2017-02-28'),
('Olivia Martinez',     'olivia.martinez@company.com',     'LATAM',         'Mid-Market Sales',   '2020-09-01'),
('Robert Kim',          'robert.kim@company.com',          'APAC',          'Enterprise Sales',   '2019-04-15'),
('Jessica Adams',       'jessica.adams@company.com',       'North America', 'Healthcare',         '2021-02-01'),
('Daniel Wright',       'daniel.wright@company.com',       'EMEA',          'Enterprise Sales',   '2018-06-15'),
('Amanda Collins',      'amanda.collins@company.com',      'North America', 'Public Sector',      '2020-11-01'),
('Christopher Lee',     'christopher.lee@company.com',     'APAC',          'Mid-Market Sales',   '2022-01-10'),
('Michelle Davis',      'michelle.davis@company.com',      'North America', 'Enterprise Sales',   '2019-08-20'),
('Andrew Taylor',       'andrew.taylor@company.com',       'EMEA',          'Public Sector',      '2020-03-01'),
('Laura Johnson',       'laura.johnson@company.com',       'North America', 'Mid-Market Sales',   '2021-07-15'),
('Kevin Patel',         'kevin.patel@company.com',         'EMEA',          'Enterprise Sales',   '2019-12-01'),
('Stephanie Brown',     'stephanie.brown@company.com',     'North America', 'Healthcare',         '2020-05-15'),
('Michael O''Brien',    'michael.obrien@company.com',      'EMEA',          'Mid-Market Sales',   '2021-03-01'),
('Catherine Wang',      'catherine.wang@company.com',      'APAC',          'Enterprise Sales',   '2018-09-15'),
('Brian Henderson',     'brian.henderson@company.com',     'North America', 'Enterprise Sales',   '2017-11-01'),
('Nicole Garcia',       'nicole.garcia@company.com',       'LATAM',         'Enterprise Sales',   '2020-08-15'),
('William Scott',       'william.scott@company.com',       'EMEA',          'Mid-Market Sales',   '2021-04-01'),
('Elizabeth Moore',     'elizabeth.moore@company.com',     'North America', 'Public Sector',      '2019-06-15'),
('Jason Park',          'jason.park@company.com',          'APAC',          'Mid-Market Sales',   '2022-03-01'),
('Rebecca Turner',      'rebecca.turner@company.com',      'North America', 'Healthcare',         '2020-10-15'),
('Gregory Hall',        'gregory.hall@company.com',        'EMEA',          'Enterprise Sales',   '2018-04-01'),
('Samantha Reed',       'samantha.reed@company.com',       'North America', 'Mid-Market Sales',   '2021-09-01'),
('Patrick Murphy',      'patrick.murphy@company.com',      'EMEA',          'Public Sector',      '2020-01-15');

-- =============================================================================
-- PROVIDERS (50 records)
-- =============================================================================

INSERT INTO providers (provider_name, provider_type, tier, country) VALUES
('CloudScale Technologies',       'Infrastructure', 'Strategic',     'United States'),
('DataVault Systems',             'Software',       'Strategic',     'United States'),
('Meridian Consulting',           'Consulting',     'Preferred',     'United Kingdom'),
('NexGen Infrastructure',         'Infrastructure', 'Preferred',     'Germany'),
('Quantum Services Group',        'Services',       'Strategic',     'United States'),
('Pacific Digital Solutions',     'Software',       'Standard',      'Japan'),
('Atlas Hardware Corp',           'Hardware',       'Preferred',     'United States'),
('Nordic Cloud Partners',         'Infrastructure', 'Standard',      'Sweden'),
('Pinnacle Support Services',     'Services',       'Transactional', 'India'),
('Sterling Software Labs',        'Software',       'Preferred',     'Canada'),
('Azure Bridge Solutions',        'Infrastructure', 'Strategic',     'United States'),
('Centric Data Platforms',        'Software',       'Preferred',     'Germany'),
('GlobalEdge Consulting',         'Consulting',     'Strategic',     'United Kingdom'),
('Hyperion Systems',              'Hardware',       'Strategic',     'United States'),
('InfraCore Technologies',        'Infrastructure', 'Preferred',     'Netherlands'),
('KeyStone Security',             'Software',       'Preferred',     'Israel'),
('LightPath Networks',            'Infrastructure', 'Standard',      'Singapore'),
('MegaByte Solutions',            'Software',       'Standard',      'India'),
('Nexus Managed Services',        'Services',       'Preferred',     'United States'),
('Omega Consulting Partners',     'Consulting',     'Preferred',     'Australia'),
('PrimeStack Infrastructure',     'Infrastructure', 'Strategic',     'United States'),
('QuickServe IT',                 'Services',       'Transactional', 'Philippines'),
('RedRock Hardware',              'Hardware',       'Standard',      'Taiwan'),
('SilverLine Software',           'Software',       'Standard',      'Poland'),
('TeraByte Cloud',                'Infrastructure', 'Preferred',     'France'),
('UltraNet Communications',       'Infrastructure', 'Standard',      'South Korea'),
('Vertex Analytics',              'Software',       'Preferred',     'United States'),
('WavePoint Consulting',          'Consulting',     'Standard',      'Canada'),
('Xenon Data Services',           'Services',       'Preferred',     'United Kingdom'),
('Zenith Platform Group',         'Software',       'Strategic',     'United States'),
('Alpine Tech Solutions',         'Infrastructure', 'Standard',      'Switzerland'),
('BluePeak Systems',              'Hardware',       'Preferred',     'Japan'),
('CyberShield Security',          'Software',       'Strategic',     'United States'),
('Delta Managed IT',              'Services',       'Standard',      'India'),
('EagleView Platforms',           'Infrastructure', 'Preferred',     'Canada'),
('FrostByte Computing',           'Hardware',       'Standard',      'Finland'),
('GreenField Cloud',              'Infrastructure', 'Standard',      'Ireland'),
('HorizonEdge Networks',          'Infrastructure', 'Preferred',     'United Kingdom'),
('IronClad Infrastructure',       'Infrastructure', 'Strategic',     'United States'),
('JetStream Services',            'Services',       'Preferred',     'Australia'),
('KiloWatt Energy IT',            'Infrastructure', 'Standard',      'Norway'),
('LunarSoft Applications',        'Software',       'Standard',      'Czech Republic'),
('MetroLink Telecom',             'Infrastructure', 'Preferred',     'Germany'),
('NovaCore Consulting',           'Consulting',     'Preferred',     'United States'),
('OptiServe Solutions',           'Services',       'Standard',      'Mexico'),
('PolarStar Hardware',            'Hardware',       'Standard',      'Sweden'),
('QuantumLeap AI',                'Software',       'Preferred',     'United States'),
('RiverStone IT',                 'Services',       'Transactional', 'Brazil'),
('SunBurst Technologies',         'Software',       'Standard',      'Spain'),
('TitanGrid Infrastructure',      'Infrastructure', 'Strategic',     'United States');

COMMIT;

-- Verify
SELECT 'account_managers' AS table_name, COUNT(*) AS row_count FROM account_managers
UNION ALL
SELECT 'providers', COUNT(*) FROM providers;
