# Demo Scenarios

## Overview

These scenarios demonstrate enterprise-grade Agentic AI capabilities. Each scenario shows the AI assistant autonomously querying business data and providing actionable insights.

---

## Scenario 1: Contract Value Increase Explanation

**User Question:** "Why did contract value increase for TechVantage Corporation this year?"

**Expected Agent Behaviour:**
1. Query contracts for TechVantage
2. Query contract_events for expansion/price change events
3. Query spend_history for YoY comparison

**Expected SQL Calls:**
```sql
SELECT * FROM v_contract_details WHERE customer_name = 'TechVantage Corporation';

SELECT * FROM contract_events ce
JOIN contracts c ON ce.contract_id = c.contract_id
JOIN customers cust ON c.customer_id = cust.customer_id
WHERE cust.customer_name = 'TechVantage Corporation'
ORDER BY ce.event_date DESC;
```

**Expected Answer Style:**
> TechVantage Corporation's contract value increased from $900K to $1.2M annually on their infrastructure contract (CTR-2020-003). This was driven by a scope expansion in January 2022 to include AI/ML infrastructure workloads. The expansion added $300K in annual value, reflecting TechVantage's growing investment in artificial intelligence capabilities on our platform.

**Business Value:** Demonstrates ability to trace revenue growth to specific business events, useful for account planning and executive briefings.

---

## Scenario 2: Renewal Risk Analysis

**User Question:** "Which customers are at highest renewal risk and what should we do?"

**Expected Agent Behaviour:**
1. Query v_renewal_risk_dashboard for open risks
2. Query support_tickets for correlated issues
3. Synthesise with recommended actions

**Expected SQL Calls:**
```sql
SELECT * FROM v_renewal_risk_dashboard ORDER BY risk_score DESC LIMIT 10;

SELECT customer_name, COUNT(*) as ticket_count,
       COUNT(*) FILTER (WHERE severity IN ('Critical','High')) as critical_high
FROM support_tickets st
JOIN customers c ON st.customer_id = c.customer_id
WHERE st.opened_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY customer_name
ORDER BY critical_high DESC;
```

**Expected Answer Style:**
> Our top renewal risks are:
> 1. **CrestWave Media Group** (Risk Score: 0.85, $310K annual value) - Multiple SLA breaches, VP escalation, declining spend. Recommend immediate executive business review.
> 2. **Evergreen Retail Co** (Risk Score: 0.78, $195K annual value) - Platform outage during flash sale, competitor evaluation suspected. Need immediate executive engagement.
> 3. **Nordic Health Systems** (Risk Score: 0.55, $520K annual value) - Contract expiring in 60 days without renewal discussion. GDPR compliance concern.

**Business Value:** Proactive risk identification enabling targeted retention actions before revenue is lost.

---

## Scenario 3: Account Manager Performance

**User Question:** "Which account manager owns the most revenue and how is their portfolio performing?"

**Expected SQL Calls:**
```sql
SELECT * FROM v_manager_portfolio ORDER BY managed_revenue DESC;

SELECT am.manager_name, COUNT(DISTINCT rr.risk_id) as open_risks,
       SUM(c.annual_value_usd) FILTER (WHERE rr.status = 'Open') as at_risk_revenue
FROM account_managers am
JOIN contracts c ON am.manager_id = c.manager_id
LEFT JOIN renewal_risks rr ON c.contract_id = rr.contract_id
GROUP BY am.manager_name
ORDER BY at_risk_revenue DESC NULLS LAST;
```

**Expected Answer Style:**
> **Thomas Baker** manages the largest portfolio at $X.XM in active revenue across Y customers. His portfolio includes our largest accounts: Horizon Aerospace ($5.19M) and Summit Energy ($2.78M).
>
> However, Emma Thompson in EMEA has the highest risk-adjusted portfolio with Z open risks totalling $XK in at-risk revenue. James Rodriguez has 2 at-risk accounts (CrestWave Media) requiring immediate attention.

**Business Value:** Sales leadership visibility into team performance and risk distribution.

---

## Scenario 4: Provider Spend Concentration

**User Question:** "Which provider has the highest total contract value? Are we too concentrated?"

**Expected SQL Calls:**
```sql
SELECT * FROM v_provider_concentration ORDER BY total_annual_value DESC;
```

**Expected Answer Style:**
> **CloudScale Technologies** dominates our provider portfolio with $X.XM in active annual contract value across XX contracts, representing XX% of total spend. This is a Strategic tier provider.
>
> Concentration Risk: Having >40% of infrastructure spend with a single provider creates dependency risk. Recommend diversification review for non-critical workloads to NexGen Infrastructure or Nordic Cloud Partners.

**Business Value:** Procurement and risk teams can assess vendor concentration and plan diversification.

---

## Scenario 5: Customer Churn Early Warning

**User Question:** "Which customers show early warning signs of potential churn?"

**Expected Agent Behaviour:**
1. Query customers with 'At Risk' status
2. Correlate with declining spend
3. Check support ticket volume
4. Check renewal risk scores

**Expected SQL Calls:**
```sql
SELECT * FROM customers WHERE status = 'At Risk';

SELECT * FROM v_annual_customer_spend
WHERE customer_id IN (SELECT customer_id FROM customers WHERE status = 'At Risk')
ORDER BY customer_name, fiscal_year;

SELECT * FROM v_support_revenue_risk
WHERE customer_id IN (SELECT customer_id FROM customers WHERE status = 'At Risk');
```

**Expected Answer Style:**
> Two customers are flagged as 'At Risk':
>
> 1. **CrestWave Media Group** - Spend declined 24% YoY (from $530K to $402K). They have 7 support tickets in the last 12 months including 2 Critical outages. Their infrastructure contract is pending renewal with no auto-renew.
>
> 2. **Evergreen Retail Co** - Had a critical platform outage during their flash sale event. 5 tickets in 6 months. Competitor evaluation suspected. Small account ($280K) but growing segment.

**Business Value:** Proactive churn prevention before customer makes decision to leave.

---

## Scenario 6: Support Tickets vs Revenue Risk

**User Question:** "Which customers have high support ticket volumes but also high revenue? Where should we prioritise service improvements?"

**Expected SQL Calls:**
```sql
SELECT * FROM v_support_revenue_risk
ORDER BY active_revenue DESC;
```

**Expected Answer Style:**
> High-revenue customers with elevated support activity:
>
> | Customer | Revenue | Tickets (12mo) | Critical/High | Avg Resolution |
> |----------|---------|----------------|---------------|----------------|
> | CrestWave Media | $310K | 7 | 5 | 48hrs |
> | Summit Energy | $2.78M | 4 | 2 | 14hrs |
>
> **Priority:** Summit Energy's issues were resolved quickly (avg 14hrs) showing good service. CrestWave's average resolution of 48hrs and 5 high-severity tickets indicate systemic service delivery problems requiring immediate process improvement.

**Business Value:** Prioritise engineering and support resources where revenue is most at risk.

---

## Scenario 7: Segment Growth Comparison

**User Question:** "Which customer segment is growing fastest?"

**Expected SQL Calls:**
```sql
SELECT * FROM v_segment_summary;

SELECT segment, fiscal_year, SUM(amount_usd) as total_spend
FROM spend_history sh
JOIN customers c ON sh.customer_id = c.customer_id
GROUP BY segment, fiscal_year
ORDER BY segment, fiscal_year;
```

**Expected Answer Style:**
> Segment revenue breakdown (active contracts):
> - **Enterprise:** $XX.XM across XX contracts (largest segment)
> - **Mid-Market:** $X.XM across XX contracts
> - **Healthcare:** $X.XM across XX contracts
> - **Public Sector:** $X.XM across XX contracts
>
> Growth analysis: Enterprise segment grew XX% YoY driven by infrastructure expansions (TechVantage AI/ML, Horizon Aerospace secure cloud). Healthcare is the fastest-growing segment by percentage due to new customer onboarding.

**Business Value:** Strategic planning and investment prioritisation by market segment.

---

## Scenario 8: Executive Summary Generation

**User Question:** "Give me an executive summary of our contract portfolio"

**Expected Agent Behaviour:**
1. Query segment summary
2. Query total portfolio metrics
3. Query upcoming renewals
4. Query top risks
5. Synthesise into executive format

**Expected SQL Calls:**
```sql
SELECT COUNT(*) as total_contracts, SUM(annual_value_usd) as total_annual_value,
       AVG(annual_value_usd) as avg_value, COUNT(DISTINCT customer_id) as customers
FROM contracts WHERE status = 'Active';

SELECT * FROM v_segment_summary;

SELECT COUNT(*) as pending_renewals, SUM(annual_value_usd) as renewal_value
FROM contracts WHERE status = 'Pending Renewal';

SELECT COUNT(*) as high_risks FROM renewal_risks WHERE risk_score > 0.7 AND status = 'Open';
```

**Expected Answer Style:**
> ## Portfolio Executive Summary
>
> **Total Active Portfolio:** $XX.XM annual value across XX contracts with XX customers.
>
> **Segment Mix:** Enterprise dominates at XX%, followed by Mid-Market (XX%), Healthcare (XX%), and Public Sector (XX%).
>
> **Upcoming Renewals:** X contracts worth $X.XM are pending renewal in the next 90 days.
>
> **Risk Alerts:** X contracts with high risk scores (>0.7) totalling $XXK in annual value require immediate attention.
>
> **Key Actions Required:**
> 1. CrestWave Media executive engagement (85% churn risk)
> 2. Nordic Health renewal initiation (expiring in 60 days)
> 3. TechVantage competitive positioning (competitor demo scheduled)

**Business Value:** Board-ready portfolio summary without manual report preparation.

---

## Demo Delivery Tips

1. **Start with Scenario 8** (Executive Summary) to show breadth
2. **Follow with Scenario 2** (Renewal Risk) to show depth and actionability
3. **Use Scenario 1** to show the agent can trace root causes
4. **End with Scenario 6** to show cross-cutting analysis
5. Always highlight that the agent chose which queries to run autonomously
6. Point out security: read-only, validated SQL, no data modification possible
7. Emphasise platform: running on IBM Power (ppc64le) with enterprise OpenShift security
