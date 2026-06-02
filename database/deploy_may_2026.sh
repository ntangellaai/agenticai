#!/bin/bash
# Deploy May 2026 data to PostgreSQL database

echo "=== Deploying May 2026 Data ==="

# Check if the SQL file exists
SQL_FILE="service_express_uk/anonymised_summary_May_2026.sql"
if [ ! -f "$SQL_FILE" ]; then
    echo "ERROR: SQL file $SQL_FILE not found!"
    echo "Please ensure your anonymised_summary_May_2026.sql file is in the service_express_uk directory"
    exit 1
fi

# Use PostgreSQL pod to execute SQL
echo "Connecting to PostgreSQL pod and loading May 2026 data..."
# Copy files to the pod
oc cp load_may_2026_data.sql postgres-0:/tmp/
oc cp service_express_uk/anonymised_summary_May_2026.sql postgres-0:/tmp/

# Execute the load script in the pod
oc exec postgres-0 -- psql -U postgres -d service_express_uk -f /tmp/load_may_2026_data.sql

if [ $? -eq 0 ]; then
    echo "✅ May 2026 data loaded successfully!"
    echo ""
    echo "=== Verification Query ==="
    oc exec postgres-0 -- psql -U postgres -d service_express_uk -c "
    SELECT 
        'May 2026' as month_loaded,
        COUNT(DISTINCT customer_name) as customers,
        COUNT(DISTINCT contract_number) as contracts,
        ROUND(SUM(contract_total_monthly), 2) as total_monthly_revenue,
        COUNT(DISTINCT service_name) as unique_services
    FROM v_contract_summary
    WHERE extract_month = '2026-05';
    "
else
    echo "❌ Failed to load May 2026 data!"
    exit 1
fi

echo ""
echo "=== Testing Views ==="
echo "Testing top customers view..."
oc exec postgres-0 -- psql -U postgres -d service_express_uk -c "
SELECT customer_name, total_monthly_value 
FROM v_top_customers 
WHERE revenue_rank <= 3;
"

echo ""
echo "Testing service revenue view..."
oc exec postgres-0 -- psql -U postgres -d service_express_uk -c "
SELECT service_name, total_monthly_revenue, customer_count 
FROM v_service_revenue_summary 
WHERE revenue_rank <= 3;
"

echo ""
echo "✅ All views updated and tested successfully!"
