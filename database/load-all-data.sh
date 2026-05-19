#!/bin/bash
# =============================================================================
# Master Data Load Script
# Runs all seed data batches in order with validation
# 
# Expected record counts after full load:
#   - account_managers: ~30
#   - providers: ~50
#   - customers: ~200
#   - contracts: ~2000
#   - contract_events: ~5000-8000
#   - spend_history: ~8000-12000
#   - support_tickets: ~2000
#   - renewal_risks: ~500
#   - document_metadata: ~500
#   TOTAL: ~18,000-25,000 records
#
# Usage (local):
#   export PGHOST=localhost PGPORT=5432 PGDATABASE=enterprise_contracts PGUSER=postgres
#   bash database/load-all-data.sh
#
# Usage (OpenShift):
#   NAMESPACE=agenticai-demo
#   PG_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].metadata.name}')
#   for f in database/seed-data-batch-*.sql; do
#     echo "Loading $f..."
#     oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$f"
#   done
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_NAME="${PGDATABASE:-enterprise_contracts}"
DB_USER="${PGUSER:-postgres}"

echo "============================================"
echo "  Enterprise Contracts - Data Load"
echo "  Database: $DB_NAME"
echo "============================================"
echo ""

# Function to run SQL file
run_sql() {
    local file="$1"
    local desc="$2"
    echo -n "  Loading $desc... "
    if psql -U "$DB_USER" -d "$DB_NAME" -f "$file" > /dev/null 2>&1; then
        echo "✅"
    else
        echo "❌ FAILED"
        echo "  Error loading $file"
        psql -U "$DB_USER" -d "$DB_NAME" -f "$file" 2>&1 | tail -5
        exit 1
    fi
}

# Step 0: Schema
echo "--- Step 0: Schema ---"
run_sql "$SCRIPT_DIR/schema.sql" "schema (tables + indexes)"

# Step 1: Reference data
echo ""
echo "--- Batch 1: Reference Data (managers + providers) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-1-reference.sql" "account managers (30) + providers (50)"

# Step 2: Customers
echo ""
echo "--- Batch 2: Customers (~200) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-2-customers.sql" "customers"

# Step 3: Contracts
echo ""
echo "--- Batch 3: Contracts (~2000) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-3-contracts.sql" "contracts"

# Step 4: Contract Events
echo ""
echo "--- Batch 4: Contract Events (~3000-6000) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-4-events.sql" "contract events"

# Step 5: Spend History
echo ""
echo "--- Batch 5: Spend History (~8000-12000) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-5-spend.sql" "spend history"

# Step 6: Support Tickets
echo ""
echo "--- Batch 6: Support Tickets (~2000) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-6-tickets.sql" "support tickets"

# Step 7: Risks + Documents
echo ""
echo "--- Batch 7: Renewal Risks + Documents (~1000) ---"
run_sql "$SCRIPT_DIR/seed-data-batch-7-risks-docs.sql" "renewal risks + documents"

# Step 8: Views
echo ""
echo "--- Views ---"
run_sql "$SCRIPT_DIR/views.sql" "business views"

# Step 9: Additional indexes
echo ""
echo "--- Performance Indexes ---"
run_sql "$SCRIPT_DIR/indexes.sql" "performance indexes + ANALYZE"

# Step 10: Roles
echo ""
echo "--- Read-Only Role ---"
run_sql "$SCRIPT_DIR/roles.sql" "mcp_readonly role + grants"

# Validation
echo ""
echo "============================================"
echo "  Validation"
echo "============================================"
echo ""

psql -U "$DB_USER" -d "$DB_NAME" -c "
SELECT table_name, row_count FROM (
    SELECT 'account_managers' AS table_name, COUNT(*) AS row_count FROM account_managers
    UNION ALL SELECT 'providers', COUNT(*) FROM providers
    UNION ALL SELECT 'customers', COUNT(*) FROM customers
    UNION ALL SELECT 'contracts', COUNT(*) FROM contracts
    UNION ALL SELECT 'contract_events', COUNT(*) FROM contract_events
    UNION ALL SELECT 'spend_history', COUNT(*) FROM spend_history
    UNION ALL SELECT 'support_tickets', COUNT(*) FROM support_tickets
    UNION ALL SELECT 'renewal_risks', COUNT(*) FROM renewal_risks
    UNION ALL SELECT 'document_metadata', COUNT(*) FROM document_metadata
) t
ORDER BY row_count DESC;
"

TOTAL=$(psql -U "$DB_USER" -d "$DB_NAME" -t -c "
SELECT SUM(cnt) FROM (
    SELECT COUNT(*) AS cnt FROM account_managers
    UNION ALL SELECT COUNT(*) FROM providers
    UNION ALL SELECT COUNT(*) FROM customers
    UNION ALL SELECT COUNT(*) FROM contracts
    UNION ALL SELECT COUNT(*) FROM contract_events
    UNION ALL SELECT COUNT(*) FROM spend_history
    UNION ALL SELECT COUNT(*) FROM support_tickets
    UNION ALL SELECT COUNT(*) FROM renewal_risks
    UNION ALL SELECT COUNT(*) FROM document_metadata
) t;
")

echo ""
echo "  TOTAL RECORDS: $TOTAL"
echo ""
echo "============================================"
echo "  ✅ Data load complete"
echo "============================================"
