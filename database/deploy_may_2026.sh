#!/bin/bash
# Deploy May 2026 data to PostgreSQL database

# Database connection parameters
DB_HOST="postgres-svc.postgres.svc.cluster.local"
DB_PORT="5432"
DB_NAME="service_express_uk"
DB_USER="postgres"
DB_PASSWORD="postgres123"

echo "=== Deploying May 2026 Data ==="
echo "Database: $DB_HOST:$DB_PORT/$DB_NAME"

# Check if the SQL file exists
SQL_FILE="service_express_uk/anonymised_summary_May_2026.sql"
if [ ! -f "$SQL_FILE" ]; then
    echo "ERROR: SQL file $SQL_FILE not found!"
    echo "Please ensure your anonymised_summary_May_2026.sql file is in the service_express_uk directory"
    exit 1
fi

# Connect to database and run the load script
echo "Connecting to database and loading May 2026 data..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f load_may_2026_data.sql

if [ $? -eq 0 ]; then
    echo "✅ May 2026 data loaded successfully!"
    echo ""
    echo "=== Verification Query ==="
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
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
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT customer_name, total_monthly_value 
FROM v_top_customers 
WHERE revenue_rank <= 3;
"

echo ""
echo "Testing service revenue view..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT service_name, total_monthly_revenue, customer_count 
FROM v_service_revenue_summary 
WHERE revenue_rank <= 3;
"

echo ""
echo "✅ All views updated and tested successfully!"
