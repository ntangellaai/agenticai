-- =============================================================================
-- BATCH 4: Contract Events (~3000 records)
-- Generates realistic timeline of contract changes
-- Depends on: Batch 3 (contracts)
-- =============================================================================

BEGIN;

DO $$
DECLARE
    v_event_types TEXT[] := ARRAY['Created', 'Renewed', 'Expanded', 'Reduced', 'Terminated', 'Price Increase', 'Scope Change', 'Escalation', 'Amendment'];
    v_descriptions_created TEXT[] := ARRAY[
        'Initial contract signed following competitive RFP process',
        'New agreement established for enterprise services',
        'Contract executed after successful proof of concept',
        'Multi-year agreement signed at executive level',
        'New service engagement initiated',
        'Contract awarded following vendor selection process',
        'Partnership agreement formalised',
        'Service agreement activated post-procurement'
    ];
    v_descriptions_expanded TEXT[] := ARRAY[
        'Additional capacity provisioned to support growth',
        'Scope expanded to include new geographic regions',
        'Added AI/ML workload support infrastructure',
        'Expanded to include disaster recovery services',
        'Additional user licenses procured',
        'New module added to existing platform',
        'Capacity doubled to support new business unit',
        'Extended coverage to include 24/7 support',
        'Added security monitoring services',
        'Expanded cloud storage allocation by 200%'
    ];
    v_descriptions_reduced TEXT[] := ARRAY[
        'Customer downsized operations, reduced capacity',
        'Budget cuts resulted in service reduction',
        'Consolidation of services led to scope decrease',
        'Customer migrated partial workload to competitor',
        'Reduced user count following restructuring',
        'Scaled back to essential services only'
    ];
    v_descriptions_price TEXT[] := ARRAY[
        'Annual CPI adjustment per contract terms',
        'Price increase reflecting enhanced service levels',
        'Contractual price escalation clause applied',
        'Rate card update effective this renewal period',
        'Inflationary adjustment applied per agreement',
        'Market rate alignment for premium services'
    ];
    v_descriptions_escalation TEXT[] := ARRAY[
        'Customer escalated due to repeated SLA breaches',
        'VP-level escalation regarding service quality',
        'Executive escalation following outage incident',
        'Formal complaint raised regarding response times',
        'Escalation due to billing discrepancies',
        'Customer threatened termination, escalated to retention team'
    ];
    v_contract RECORD;
    v_event_type TEXT;
    v_event_date DATE;
    v_description TEXT;
    v_old_value NUMERIC;
    v_new_value NUMERIC;
    v_manager_name TEXT;
    v_num_events INTEGER;
    j INTEGER;
BEGIN
    -- For each contract, generate 1-4 events
    FOR v_contract IN
        SELECT c.contract_id, c.start_date, c.end_date, c.annual_value_usd, 
               c.status, am.manager_name
        FROM contracts c
        JOIN account_managers am ON c.manager_id = am.manager_id
    LOOP
        -- Every contract gets a 'Created' event
        INSERT INTO contract_events (contract_id, event_type, event_date, description, old_value_usd, new_value_usd, changed_by)
        VALUES (
            v_contract.contract_id,
            'Created',
            v_contract.start_date,
            v_descriptions_created[1 + floor(random() * array_length(v_descriptions_created, 1))::int],
            NULL,
            v_contract.annual_value_usd,
            v_contract.manager_name
        );

        -- Generate 0-3 additional events
        v_num_events := floor(random() * 4)::int;
        v_old_value := v_contract.annual_value_usd;

        FOR j IN 1..v_num_events LOOP
            -- Pick event type based on contract status (weighted)
            IF v_contract.status = 'Terminated' AND j = v_num_events THEN
                v_event_type := 'Terminated';
            ELSIF v_contract.status = 'Renewed' AND j = v_num_events THEN
                v_event_type := 'Renewed';
            ELSIF random() < 0.3 THEN
                v_event_type := 'Expanded';
            ELSIF random() < 0.5 THEN
                v_event_type := 'Price Increase';
            ELSIF random() < 0.65 THEN
                v_event_type := 'Scope Change';
            ELSIF random() < 0.75 THEN
                v_event_type := 'Escalation';
            ELSIF random() < 0.85 THEN
                v_event_type := 'Reduced';
            ELSE
                v_event_type := 'Amendment';
            END IF;

            -- Event date: between start and end (or now)
            v_event_date := v_contract.start_date + 
                            (j * (LEAST(v_contract.end_date, CURRENT_DATE) - v_contract.start_date) / (v_num_events + 1));

            -- Calculate value change
            CASE v_event_type
                WHEN 'Expanded' THEN
                    v_new_value := v_old_value * (1 + random() * 0.4 + 0.1);  -- 10-50% increase
                    v_description := v_descriptions_expanded[1 + floor(random() * array_length(v_descriptions_expanded, 1))::int];
                WHEN 'Reduced' THEN
                    v_new_value := v_old_value * (1 - random() * 0.3 - 0.05); -- 5-35% decrease
                    v_description := v_descriptions_reduced[1 + floor(random() * array_length(v_descriptions_reduced, 1))::int];
                WHEN 'Price Increase' THEN
                    v_new_value := v_old_value * (1 + random() * 0.08 + 0.02); -- 2-10% increase
                    v_description := v_descriptions_price[1 + floor(random() * array_length(v_descriptions_price, 1))::int];
                WHEN 'Escalation' THEN
                    v_new_value := NULL;
                    v_old_value := NULL;
                    v_description := v_descriptions_escalation[1 + floor(random() * array_length(v_descriptions_escalation, 1))::int];
                WHEN 'Renewed' THEN
                    v_new_value := v_old_value * (1 + random() * 0.1);
                    v_description := 'Contract renewed with updated terms';
                WHEN 'Terminated' THEN
                    v_new_value := 0;
                    v_description := 'Contract terminated - customer decision';
                ELSE
                    v_new_value := v_old_value;
                    v_description := 'Administrative amendment to contract terms';
            END CASE;

            INSERT INTO contract_events (contract_id, event_type, event_date, description, old_value_usd, new_value_usd, changed_by)
            VALUES (
                v_contract.contract_id,
                v_event_type,
                v_event_date,
                v_description,
                CASE WHEN v_event_type != 'Escalation' THEN round(v_old_value, 2) ELSE NULL END,
                CASE WHEN v_event_type != 'Escalation' THEN round(v_new_value, 2) ELSE NULL END,
                v_contract.manager_name
            );

            -- Update running value for next event
            IF v_new_value IS NOT NULL AND v_new_value > 0 THEN
                v_old_value := v_new_value;
            END IF;
        END LOOP;
    END LOOP;
END $$;

COMMIT;

-- Verify
SELECT event_type, COUNT(*) AS count
FROM contract_events 
GROUP BY event_type 
ORDER BY count DESC;
