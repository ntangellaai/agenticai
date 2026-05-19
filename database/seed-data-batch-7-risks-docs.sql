-- =============================================================================
-- BATCH 7: Renewal Risks (~500 records) + Document Metadata (~500 records)
-- Generates risk assessments and document references
-- Depends on: Batch 2, Batch 3
-- =============================================================================

BEGIN;

-- =============================================================================
-- RENEWAL RISKS (~500 records)
-- Generate risk assessments for contracts expiring within 12 months
-- or contracts with high support ticket counts
-- =============================================================================

DO $$
DECLARE
    v_risk_factors_pool TEXT[] := ARRAY[
        'Multiple SLA breaches in last 6 months',
        'Customer escalation to VP/C-level',
        'Declining spend year-over-year',
        'High support ticket volume',
        'No auto-renew clause',
        'Competitor evaluation confirmed',
        'Budget review in progress',
        'Key stakeholder departed customer',
        'Customer restructuring/M&A activity',
        'No executive relationship established',
        'Contract expiring without renewal discussion',
        'Pricing above market rate',
        'Customer satisfaction score declining',
        'Delayed invoice payments',
        'Reduced usage metrics',
        'Compliance/regulatory concern raised',
        'Failed QBR meeting attendance',
        'Customer published RFP for similar services',
        'Previous renewal was contentious',
        'Customer requesting shorter term'
    ];
    v_actions_pool TEXT[] := ARRAY[
        'Schedule executive business review immediately',
        'Prepare service improvement plan with committed SLAs',
        'Offer loyalty discount or credit for retention',
        'Initiate proactive renewal discussion',
        'Assign dedicated technical account manager',
        'Prepare competitive positioning document',
        'Engage customer success team for health check',
        'Schedule quarterly business review',
        'Propose multi-year renewal with discount',
        'Prepare ROI analysis demonstrating value delivered',
        'Escalate internally to VP Sales for executive engagement',
        'Offer proof-of-concept for new capabilities',
        'Prepare migration/transition support proposal',
        'Conduct win-back strategy planning session',
        'Initiate contract renegotiation with improved terms'
    ];
    v_contract RECORD;
    v_risk_score NUMERIC;
    v_num_factors INTEGER;
    v_factors TEXT[];
    v_action TEXT;
    v_status TEXT;
    i INTEGER;
    j INTEGER;
BEGIN
    -- Generate risks for contracts that are pending renewal, expiring soon, or random active ones
    FOR v_contract IN
        SELECT ct.contract_id, ct.end_date, ct.annual_value_usd, ct.status,
               ct.manager_id, ct.auto_renew
        FROM contracts ct
        WHERE ct.status IN ('Active', 'Pending Renewal')
        AND (
            -- Expiring within 12 months
            ct.end_date <= CURRENT_DATE + INTERVAL '12 months'
            -- Or randomly selected (20% of active contracts get assessed)
            OR random() < 0.2
        )
        LIMIT 500
    LOOP
        -- Calculate risk score based on factors
        IF v_contract.status = 'Pending Renewal' THEN
            v_risk_score := 0.4 + random() * 0.5;  -- 0.40 - 0.90
        ELSIF NOT v_contract.auto_renew THEN
            v_risk_score := 0.3 + random() * 0.5;  -- 0.30 - 0.80
        ELSE
            v_risk_score := 0.1 + random() * 0.4;  -- 0.10 - 0.50
        END IF;

        -- Number of risk factors (more factors = higher score)
        v_num_factors := GREATEST(1, LEAST(5, floor(v_risk_score * 6)::int));

        -- Pick random factors
        v_factors := ARRAY[]::TEXT[];
        FOR j IN 1..v_num_factors LOOP
            v_factors := array_append(v_factors, 
                v_risk_factors_pool[1 + floor(random() * array_length(v_risk_factors_pool, 1))::int]);
        END LOOP;

        -- Pick action
        v_action := v_actions_pool[1 + floor(random() * array_length(v_actions_pool, 1))::int];

        -- Status
        IF random() < 0.65 THEN
            v_status := 'Open';
        ELSIF random() < 0.8 THEN
            v_status := 'Mitigated';
        ELSIF random() < 0.9 THEN
            v_status := 'Renewed';
        ELSE
            v_status := 'Lost';
        END IF;

        INSERT INTO renewal_risks (
            contract_id, risk_score, risk_factors, assessed_date,
            recommended_action, owner_manager_id, status
        ) VALUES (
            v_contract.contract_id,
            round(v_risk_score, 2),
            v_factors,
            CURRENT_DATE - floor(random() * 90)::int,  -- Assessed in last 90 days
            v_action,
            v_contract.manager_id,
            v_status
        );
    END LOOP;
END $$;

-- =============================================================================
-- DOCUMENT METADATA (~500 records)
-- Generates references to contract documents, meeting notes, etc.
-- =============================================================================

DO $$
DECLARE
    v_doc_types TEXT[] := ARRAY['Contract PDF', 'Amendment', 'Meeting Notes', 'Risk Assessment', 'QBR Deck', 'Escalation Report', 'Renewal Proposal'];
    v_title_prefixes TEXT[] := ARRAY[
        'Quarterly Business Review',
        'Annual Strategic Review',
        'Service Level Agreement',
        'Statement of Work',
        'Change Order',
        'Executive Summary',
        'Technical Architecture Review',
        'Security Assessment Report',
        'Compliance Audit Report',
        'Budget Planning Document',
        'Renewal Negotiation Notes',
        'Escalation Resolution Summary',
        'Performance Improvement Plan',
        'Migration Planning Document',
        'Risk Mitigation Strategy'
    ];
    v_summaries TEXT[] := ARRAY[
        'Comprehensive review of service delivery, SLA performance, and strategic roadmap',
        'Detailed analysis of contract terms, pricing, and service level commitments',
        'Executive summary of quarterly performance metrics and upcoming milestones',
        'Technical assessment of infrastructure capacity and growth requirements',
        'Financial analysis of contract value and return on investment',
        'Risk evaluation documenting potential threats and mitigation strategies',
        'Meeting notes capturing key decisions and action items from executive session',
        'Proposal outlining renewal terms with enhanced service offerings',
        'Compliance documentation demonstrating adherence to regulatory requirements',
        'Architecture review for planned expansion of services',
        'Change management documentation for service modifications',
        'Incident post-mortem analysis with root cause and corrective actions',
        'Customer feedback summary from satisfaction survey results',
        'Competitive analysis informing retention strategy',
        'Operational excellence report highlighting service improvements'
    ];
    v_contract RECORD;
    v_doc_type TEXT;
    v_title TEXT;
    v_summary TEXT;
    v_cust_name TEXT;
    v_num_docs INTEGER;
    j INTEGER;
BEGIN
    FOR v_contract IN
        SELECT ct.contract_id, ct.customer_id, ct.contract_ref, 
               ct.start_date, c.customer_name
        FROM contracts ct
        JOIN customers c ON ct.customer_id = c.customer_id
        WHERE ct.status IN ('Active', 'Pending Renewal', 'Renewed')
        ORDER BY random()
        LIMIT 250  -- ~2 docs per contract on average = ~500 docs
    LOOP
        v_num_docs := 1 + floor(random() * 3)::int;

        FOR j IN 1..v_num_docs LOOP
            v_doc_type := v_doc_types[1 + floor(random() * array_length(v_doc_types, 1))::int];
            v_title := v_contract.customer_name || ' - ' || 
                       v_title_prefixes[1 + floor(random() * array_length(v_title_prefixes, 1))::int];
            v_summary := v_summaries[1 + floor(random() * array_length(v_summaries, 1))::int];

            INSERT INTO document_metadata (
                contract_id, customer_id, document_type, title, summary,
                storage_path, created_date
            ) VALUES (
                v_contract.contract_id,
                v_contract.customer_id,
                v_doc_type,
                v_title,
                v_summary,
                '/docs/' || lower(replace(v_doc_type, ' ', '-')) || '/' || 
                    v_contract.contract_ref || '-' || j || '.pdf',
                v_contract.start_date + floor(random() * 365 * 2)::int
            );
        END LOOP;
    END LOOP;
END $$;

COMMIT;

-- Verify
SELECT 'renewal_risks' AS table_name, COUNT(*) AS row_count FROM renewal_risks
UNION ALL
SELECT 'document_metadata', COUNT(*) FROM document_metadata;

-- Risk score distribution
SELECT 
    CASE 
        WHEN risk_score >= 0.8 THEN 'Critical (0.8-1.0)'
        WHEN risk_score >= 0.6 THEN 'High (0.6-0.8)'
        WHEN risk_score >= 0.4 THEN 'Medium (0.4-0.6)'
        ELSE 'Low (0.0-0.4)'
    END AS risk_level,
    COUNT(*) AS count,
    ROUND(AVG(risk_score), 2) AS avg_score
FROM renewal_risks
GROUP BY 1
ORDER BY avg_score DESC;
