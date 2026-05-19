-- =============================================================================
-- BATCH 2: Customers (~200 records)
-- Generates realistic enterprise customer base
-- Depends on: Batch 1 (reference data)
-- =============================================================================

BEGIN;

-- Use a DO block to generate customers procedurally
DO $$
DECLARE
    v_segments TEXT[] := ARRAY['Enterprise', 'Mid-Market', 'SMB', 'Public Sector', 'Healthcare'];
    v_industries TEXT[] := ARRAY[
        'Financial Services', 'Technology', 'Healthcare', 'Manufacturing', 'Energy',
        'Retail', 'Logistics', 'Media', 'Insurance', 'Aerospace',
        'Telecommunications', 'Pharmaceuticals', 'Automotive', 'Mining',
        'Education', 'Government', 'Research', 'Real Estate', 'Agriculture', 'Defence'
    ];
    v_regions TEXT[] := ARRAY['North America', 'EMEA', 'APAC', 'LATAM'];
    v_statuses TEXT[] := ARRAY['Active', 'Active', 'Active', 'Active', 'Active', 'Active', 'Active', 'At Risk', 'Churned', 'Active'];
    v_prefixes TEXT[] := ARRAY[
        'Meridian', 'TechVantage', 'Nordic', 'Pacific', 'Summit', 'Lighthouse',
        'Velocity', 'CrestWave', 'Pinnacle', 'Dragon Gate', 'Federal', 'Greenfield',
        'Sapphire', 'Horizon', 'BrightPath', 'Coastal', 'Atlas', 'Evergreen',
        'Quantum', 'Sterling', 'Apex', 'Granite', 'Silverline', 'IronBridge',
        'GoldCrest', 'BluePeak', 'RedOak', 'WhiteStone', 'BlackRock', 'DeepWater',
        'HighPoint', 'LongView', 'WideField', 'SharpEdge', 'BoldStep', 'SwiftCurrent',
        'TrueNorth', 'FairWind', 'StrongHold', 'BrightStar', 'ClearPath', 'PrimeLine',
        'NextWave', 'CoreLink', 'DataBridge', 'CloudPeak', 'NetSphere', 'TechForge',
        'InfoPulse', 'CyberVault'
    ];
    v_suffixes TEXT[] := ARRAY[
        'Corporation', 'Group', 'Systems', 'Solutions', 'Ltd', 'Holdings',
        'Partners', 'Inc', 'Technologies', 'Services', 'Networks', 'Enterprises',
        'International', 'Industries', 'Co', 'Trust', 'Alliance', 'Dynamics',
        'Global', 'Capital'
    ];
    v_segment TEXT;
    v_industry TEXT;
    v_region TEXT;
    v_status TEXT;
    v_revenue NUMERIC;
    v_employees INTEGER;
    v_name TEXT;
    i INTEGER;
BEGIN
    FOR i IN 1..200 LOOP
        v_segment := v_segments[1 + floor(random() * array_length(v_segments, 1))::int];
        v_industry := v_industries[1 + floor(random() * array_length(v_industries, 1))::int];
        v_region := v_regions[1 + floor(random() * array_length(v_regions, 1))::int];
        v_status := v_statuses[1 + floor(random() * array_length(v_statuses, 1))::int];

        -- Generate realistic revenue based on segment
        CASE v_segment
            WHEN 'Enterprise' THEN
                v_revenue := (random() * 8000 + 2000) * 1000000;  -- 2B-10B
                v_employees := (random() * 40000 + 5000)::int;
            WHEN 'Mid-Market' THEN
                v_revenue := (random() * 800 + 200) * 1000000;    -- 200M-1B
                v_employees := (random() * 4000 + 500)::int;
            WHEN 'SMB' THEN
                v_revenue := (random() * 80 + 10) * 1000000;      -- 10M-90M
                v_employees := (random() * 400 + 20)::int;
            WHEN 'Public Sector' THEN
                v_revenue := (random() * 500 + 100) * 1000000;    -- 100M-600M (budget)
                v_employees := (random() * 10000 + 1000)::int;
            WHEN 'Healthcare' THEN
                v_revenue := (random() * 3000 + 500) * 1000000;   -- 500M-3.5B
                v_employees := (random() * 15000 + 2000)::int;
        END CASE;

        -- Generate unique name
        v_name := v_prefixes[1 + floor(random() * array_length(v_prefixes, 1))::int]
                  || ' ' || v_suffixes[1 + floor(random() * array_length(v_suffixes, 1))::int]
                  || CASE WHEN random() > 0.7 THEN ' ' || v_region ELSE '' END;

        -- Deduplicate by appending number if needed
        v_name := v_name || CASE WHEN i > 50 THEN ' ' || (i % 100)::text ELSE '' END;

        INSERT INTO customers (customer_name, segment, industry, region, annual_revenue_usd, employee_count, onboarded_date, status)
        VALUES (
            v_name,
            v_segment,
            v_industry,
            v_region,
            round(v_revenue, 2),
            v_employees,
            DATE '2018-01-01' + (random() * 2000)::int,  -- Random date 2018-2023
            v_status
        )
        ON CONFLICT DO NOTHING;
    END LOOP;
END $$;

COMMIT;

-- Verify
SELECT segment, COUNT(*) AS count, 
       ROUND(AVG(annual_revenue_usd)/1000000, 0) AS avg_revenue_millions
FROM customers 
GROUP BY segment 
ORDER BY count DESC;
