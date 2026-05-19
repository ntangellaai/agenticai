-- =============================================================================
-- BATCH 6: Support Tickets (~2000 records)
-- Generates realistic support ticket history
-- Depends on: Batch 2 (customers), Batch 3 (contracts)
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_severities TEXT[] := ARRAY['Critical', 'High', 'Medium', 'Low'];
    v_severity_weights FLOAT[] := ARRAY[0.08, 0.22, 0.40, 0.30]; -- realistic distribution
    v_categories TEXT[] := ARRAY[
        'Performance', 'Outage', 'Security', 'Configuration', 'Billing',
        'Compliance', 'Feature Request', 'Hardware', 'Network', 'Integration',
        'Access Management', 'Data Issue', 'Monitoring', 'Backup/Recovery'
    ];
    v_subjects_performance TEXT[] := ARRAY[
        'Response times exceeding SLA thresholds',
        'Batch processing slower than expected',
        'API latency above acceptable limits',
        'Database query performance degradation',
        'Storage IOPS below contracted levels',
        'CPU throttling detected on production workloads',
        'Memory utilisation causing swap activity',
        'Network throughput below baseline'
    ];
    v_subjects_outage TEXT[] := ARRAY[
        'Complete service unavailability',
        'Partial outage affecting production systems',
        'Failover did not trigger during incident',
        'Scheduled maintenance extended beyond window',
        'DNS resolution failure affecting services',
        'Load balancer health check failures',
        'Certificate expiry caused service disruption',
        'Database connection pool exhaustion'
    ];
    v_subjects_security TEXT[] := ARRAY[
        'Vulnerability scan flagged unpatched components',
        'Suspected unauthorized access attempt',
        'Certificate rotation required urgently',
        'Security audit finding needs remediation',
        'Penetration test revealed exposure',
        'Access logs showing anomalous patterns',
        'Encryption key rotation overdue',
        'Compliance scan failed on security controls'
    ];
    v_subjects_config TEXT[] := ARRAY[
        'DNS record update required',
        'Firewall rule change request',
        'SSL certificate renewal needed',
        'Load balancer configuration update',
        'Resource quota adjustment needed',
        'Monitoring threshold tuning required',
        'Backup schedule modification requested',
        'Network route configuration change'
    ];
    v_subjects_billing TEXT[] := ARRAY[
        'Invoice discrepancy for recent quarter',
        'Overcharged for services not consumed',
        'Credit note required for outage period',
        'Billing address update needed',
        'Usage report not matching expected values',
        'Contract terms not reflected in invoice',
        'Duplicate charge identified',
        'Tax exemption not applied correctly'
    ];
    v_statuses TEXT[] := ARRAY['Open', 'In Progress', 'Resolved', 'Closed', 'Escalated'];
    v_status_weights FLOAT[] := ARRAY[0.10, 0.08, 0.25, 0.50, 0.07];
    v_customer RECORD;
    v_contract_id INTEGER;
    v_severity TEXT;
    v_category TEXT;
    v_subject TEXT;
    v_status TEXT;
    v_opened DATE;
    v_resolved DATE;
    v_resolution_hours NUMERIC;
    v_num_tickets INTEGER;
    v_rand FLOAT;
    j INTEGER;
BEGIN
    -- For each customer, generate tickets proportional to their risk level
    FOR v_customer IN
        SELECT c.customer_id, c.status AS cust_status, c.segment
        FROM customers c
        WHERE c.status != 'Prospect'
    LOOP
        -- Determine number of tickets based on customer status
        CASE v_customer.cust_status
            WHEN 'At Risk' THEN
                v_num_tickets := 8 + floor(random() * 12)::int;  -- 8-20 tickets
            WHEN 'Churned' THEN
                v_num_tickets := 5 + floor(random() * 8)::int;   -- 5-13 tickets
            ELSE
                v_num_tickets := 1 + floor(random() * 8)::int;   -- 1-9 tickets
        END CASE;

        -- Enterprise customers tend to have more tickets (more usage)
        IF v_customer.segment = 'Enterprise' THEN
            v_num_tickets := v_num_tickets + floor(random() * 5)::int;
        END IF;

        FOR j IN 1..v_num_tickets LOOP
            -- Pick a random contract for this customer
            SELECT contract_id INTO v_contract_id
            FROM contracts
            WHERE customer_id = v_customer.customer_id
            ORDER BY random()
            LIMIT 1;

            -- Severity (weighted random)
            v_rand := random();
            IF v_rand < v_severity_weights[1] THEN
                v_severity := 'Critical';
            ELSIF v_rand < v_severity_weights[1] + v_severity_weights[2] THEN
                v_severity := 'High';
            ELSIF v_rand < v_severity_weights[1] + v_severity_weights[2] + v_severity_weights[3] THEN
                v_severity := 'Medium';
            ELSE
                v_severity := 'Low';
            END IF;

            -- At Risk customers get more high-severity tickets
            IF v_customer.cust_status = 'At Risk' AND random() > 0.5 THEN
                IF v_severity = 'Low' THEN v_severity := 'Medium'; END IF;
                IF v_severity = 'Medium' AND random() > 0.6 THEN v_severity := 'High'; END IF;
            END IF;

            -- Category and subject
            v_category := v_categories[1 + floor(random() * array_length(v_categories, 1))::int];
            
            CASE v_category
                WHEN 'Performance' THEN
                    v_subject := v_subjects_performance[1 + floor(random() * array_length(v_subjects_performance, 1))::int];
                WHEN 'Outage' THEN
                    v_subject := v_subjects_outage[1 + floor(random() * array_length(v_subjects_outage, 1))::int];
                WHEN 'Security' THEN
                    v_subject := v_subjects_security[1 + floor(random() * array_length(v_subjects_security, 1))::int];
                WHEN 'Configuration' THEN
                    v_subject := v_subjects_config[1 + floor(random() * array_length(v_subjects_config, 1))::int];
                WHEN 'Billing' THEN
                    v_subject := v_subjects_billing[1 + floor(random() * array_length(v_subjects_billing, 1))::int];
                ELSE
                    v_subject := v_category || ' issue requiring attention - ticket ' || j::text;
            END CASE;

            -- Status (weighted)
            v_rand := random();
            IF v_rand < v_status_weights[1] THEN
                v_status := 'Open';
            ELSIF v_rand < v_status_weights[1] + v_status_weights[2] THEN
                v_status := 'In Progress';
            ELSIF v_rand < v_status_weights[1] + v_status_weights[2] + v_status_weights[3] THEN
                v_status := 'Resolved';
            ELSIF v_rand < v_status_weights[1] + v_status_weights[2] + v_status_weights[3] + v_status_weights[4] THEN
                v_status := 'Closed';
            ELSE
                v_status := 'Escalated';
            END IF;

            -- Opened date: within last 2 years
            v_opened := CURRENT_DATE - (floor(random() * 730)::int);

            -- Resolution date and hours (only if resolved/closed)
            IF v_status IN ('Resolved', 'Closed') THEN
                CASE v_severity
                    WHEN 'Critical' THEN
                        v_resolution_hours := round((random() * 24 + 2)::numeric, 2);   -- 2-26 hours
                    WHEN 'High' THEN
                        v_resolution_hours := round((random() * 72 + 4)::numeric, 2);   -- 4-76 hours
                    WHEN 'Medium' THEN
                        v_resolution_hours := round((random() * 168 + 8)::numeric, 2);  -- 8-176 hours
                    WHEN 'Low' THEN
                        v_resolution_hours := round((random() * 720 + 24)::numeric, 2); -- 24-744 hours
                END CASE;
                v_resolved := v_opened + ceil(v_resolution_hours / 24.0)::int;
            ELSE
                v_resolved := NULL;
                v_resolution_hours := NULL;
            END IF;

            INSERT INTO support_tickets (
                customer_id, contract_id, severity, category, subject,
                status, opened_date, resolved_date, resolution_hours
            ) VALUES (
                v_customer.customer_id,
                v_contract_id,
                v_severity,
                v_category,
                v_subject,
                v_status,
                v_opened,
                v_resolved,
                v_resolution_hours
            );
        END LOOP;
    END LOOP;
END $$;

COMMIT;

-- Verify
SELECT severity, status, COUNT(*) AS count
FROM support_tickets
GROUP BY severity, status
ORDER BY severity, status;
