#!/bin/bash
# =============================================================================
# Test: MCP Server functionality
# Tests the MCP server tools via direct HTTP calls
# =============================================================================

set -euo pipefail

NAMESPACE="agenticai-demo"
PASS=0
FAIL=0

# Get MCP server URL (port-forward for local testing)
MCP_URL="${MCP_URL:-http://localhost:3000}"

echo "=== MCP Server Test Suite ==="
echo "Target: $MCP_URL"
echo ""

# Helper
check_http() {
    local desc="$1"
    local method="$2"
    local url="$3"
    local data="$4"
    local expect="$5"
    
    echo -n "  [$desc]... "
    
    if [ "$method" = "GET" ]; then
        RESPONSE=$(curl -s "$url")
    else
        RESPONSE=$(curl -s -X POST "$url" -H "Content-Type: application/json" -d "$data")
    fi
    
    if echo "$RESPONSE" | grep -q "$expect"; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "❌ FAIL (expected '$expect')"
        echo "    Response: ${RESPONSE:0:200}"
        ((FAIL++))
    fi
}

# 1. Health check
echo "--- Health Check ---"
check_http "Health endpoint returns healthy" \
    "GET" "$MCP_URL/health" "" "healthy"

# 2. MCP tool calls via JSON-RPC
echo ""
echo "--- MCP Tool: list_tables ---"
check_http "list_tables returns table names" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"1","method":"tools/call","params":{"name":"list_tables","arguments":{}}}' \
    "customers"

# 3. describe_table
echo ""
echo "--- MCP Tool: describe_table ---"
check_http "describe_table returns columns for customers" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"describe_table","arguments":{"table":"customers"}}}' \
    "customer_name"

# 4. query - valid SELECT
echo ""
echo "--- MCP Tool: query (valid) ---"
check_http "Simple SELECT returns data" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"query","arguments":{"sql":"SELECT customer_name FROM customers LIMIT 3"}}}' \
    "customer_name"

check_http "Aggregate query works" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"4","method":"tools/call","params":{"name":"query","arguments":{"sql":"SELECT COUNT(*) as total FROM contracts WHERE status = '\''Active'\''"}}}' \
    "total"

check_http "View query works" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"5","method":"tools/call","params":{"name":"query","arguments":{"sql":"SELECT * FROM v_segment_summary"}}}' \
    "segment"

# 5. query - blocked operations
echo ""
echo "--- MCP Tool: query (blocked) ---"
check_http "INSERT is blocked" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"6","method":"tools/call","params":{"name":"query","arguments":{"sql":"INSERT INTO customers (customer_name) VALUES ('\''hacked'\'')"}}}' \
    "Error"

check_http "DELETE is blocked" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"7","method":"tools/call","params":{"name":"query","arguments":{"sql":"DELETE FROM customers WHERE customer_id = 1"}}}' \
    "Error"

check_http "DROP is blocked" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"8","method":"tools/call","params":{"name":"query","arguments":{"sql":"DROP TABLE customers"}}}' \
    "Error"

check_http "UPDATE is blocked" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"9","method":"tools/call","params":{"name":"query","arguments":{"sql":"UPDATE customers SET status = '\''Churned'\'' WHERE customer_id = 1"}}}' \
    "Error"

check_http "Multi-statement is blocked" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"10","method":"tools/call","params":{"name":"query","arguments":{"sql":"SELECT 1; DROP TABLE customers;"}}}' \
    "Error"

# 6. SQL injection attempts
echo ""
echo "--- SQL Injection Tests ---"
check_http "UNION-based injection attempt handled" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"11","method":"tools/call","params":{"name":"query","arguments":{"sql":"SELECT * FROM customers WHERE customer_id = 1 UNION SELECT * FROM pg_shadow"}}}' \
    ""

check_http "describe_table injection blocked" \
    "POST" "$MCP_URL/messages?sessionId=test" \
    '{"jsonrpc":"2.0","id":"12","method":"tools/call","params":{"name":"describe_table","arguments":{"table":"customers; DROP TABLE contracts; --"}}}' \
    "Invalid table name"

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ $FAIL -gt 0 ]; then
    exit 1
fi
