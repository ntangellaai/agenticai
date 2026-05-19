#!/bin/bash
# =============================================================================
# Test: Read-only access enforcement
# Verifies that the mcp_readonly user cannot perform write operations
# =============================================================================

set -euo pipefail

NAMESPACE="agenticai-demo"
PG_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].metadata.name}')
PASS=0
FAIL=0

echo "=== Read-Only Access Enforcement Tests ==="
echo "Pod: $PG_POD"
echo ""

# Helper: run SQL as mcp_readonly user
run_as_readonly() {
    oc exec $PG_POD -n $NAMESPACE -- psql -U mcp_readonly -d enterprise_contracts -c "$1" 2>&1
}

# Helper: check that a command FAILS (expected for write operations)
expect_fail() {
    local desc="$1"
    local sql="$2"
    echo -n "  [$desc]... "
    if run_as_readonly "$sql" 2>&1 | grep -qi "permission denied\|ERROR\|not allowed"; then
        echo "✅ PASS (correctly denied)"
        ((PASS++))
    else
        echo "❌ FAIL (should have been denied!)"
        ((FAIL++))
    fi
}

# Helper: check that a command SUCCEEDS
expect_pass() {
    local desc="$1"
    local sql="$2"
    echo -n "  [$desc]... "
    if run_as_readonly "$sql" 2>&1 | grep -qi "ERROR\|permission denied"; then
        echo "❌ FAIL (should have succeeded)"
        ((FAIL++))
    else
        echo "✅ PASS"
        ((PASS++))
    fi
}

# === READ operations (should PASS) ===
echo "--- Read Operations (should succeed) ---"
expect_pass "SELECT from customers" \
    "SELECT customer_name FROM customers LIMIT 1;"

expect_pass "SELECT from contracts" \
    "SELECT contract_ref FROM contracts LIMIT 1;"

expect_pass "SELECT from views" \
    "SELECT * FROM v_customer_overview LIMIT 1;"

expect_pass "Count query" \
    "SELECT COUNT(*) FROM contracts;"

expect_pass "JOIN query" \
    "SELECT c.customer_name, ct.contract_ref FROM customers c JOIN contracts ct ON c.customer_id = ct.customer_id LIMIT 1;"

expect_pass "Aggregate query" \
    "SELECT segment, SUM(annual_value_usd) FROM contracts ct JOIN customers c ON ct.customer_id = c.customer_id GROUP BY segment;"

# === WRITE operations (should FAIL) ===
echo ""
echo "--- Write Operations (should be denied) ---"
expect_fail "INSERT into customers" \
    "INSERT INTO customers (customer_name, segment, industry, region, onboarded_date) VALUES ('Test', 'SMB', 'Tech', 'EMEA', '2024-01-01');"

expect_fail "UPDATE customers" \
    "UPDATE customers SET status = 'Churned' WHERE customer_id = 1;"

expect_fail "DELETE from customers" \
    "DELETE FROM customers WHERE customer_id = 1;"

expect_fail "TRUNCATE table" \
    "TRUNCATE TABLE customers;"

expect_fail "DROP table" \
    "DROP TABLE customers;"

expect_fail "CREATE table" \
    "CREATE TABLE test_hack (id int);"

expect_fail "ALTER table" \
    "ALTER TABLE customers ADD COLUMN hacked BOOLEAN;"

# === DDL/Admin operations (should FAIL) ===
echo ""
echo "--- Admin Operations (should be denied) ---"
expect_fail "GRANT permissions" \
    "GRANT ALL ON customers TO mcp_readonly;"

expect_fail "CREATE ROLE" \
    "CREATE ROLE hacker WITH LOGIN PASSWORD 'hacked';"

expect_fail "COPY command" \
    "COPY customers TO '/tmp/data.csv';"

# === Statement timeout test ===
echo ""
echo "--- Statement Timeout ---"
echo -n "  [Long query times out]... "
TIMEOUT_RESULT=$(run_as_readonly "SELECT pg_sleep(35);" 2>&1)
if echo "$TIMEOUT_RESULT" | grep -qi "canceling statement\|timeout"; then
    echo "✅ PASS (timed out as expected)"
    ((PASS++))
else
    echo "⚠️  WARN (timeout may not be configured)"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ $FAIL -gt 0 ]; then
    echo "⚠️  SECURITY ISSUE: Some write operations were not properly blocked!"
    exit 1
else
    echo "✅ All write operations correctly denied. Read-only enforcement confirmed."
fi
