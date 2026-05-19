#!/bin/bash
# =============================================================================
# Test: Connectivity between all components
# Run from a machine with oc CLI access to the cluster
# =============================================================================

set -euo pipefail

NAMESPACE="agenticai-demo"
PASS=0
FAIL=0

echo "=== Connectivity Test Suite ==="
echo "Namespace: $NAMESPACE"
echo ""

# Helper function
check() {
    local desc="$1"
    local cmd="$2"
    echo -n "  [$desc]... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "✅ PASS"
        ((PASS++))
    else
        echo "❌ FAIL"
        ((FAIL++))
    fi
}

# 1. Check pods are running
echo "--- Pod Status ---"
check "PostgreSQL pod is Running" \
    "oc get pod -n $NAMESPACE -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].status.phase}' | grep -q Running"

check "MCP Server pod is Running" \
    "oc get pod -n $NAMESPACE -l app.kubernetes.io/name=mcp-server -o jsonpath='{.items[0].status.phase}' | grep -q Running"

check "Agent pod is Running" \
    "oc get pod -n $NAMESPACE -l app.kubernetes.io/name=agent -o jsonpath='{.items[0].status.phase}' | grep -q Running"

# 2. Check services exist
echo ""
echo "--- Services ---"
check "postgres-svc exists" \
    "oc get svc postgres-svc -n $NAMESPACE"

check "mcp-server-svc exists" \
    "oc get svc mcp-server-svc -n $NAMESPACE"

check "agent-svc exists" \
    "oc get svc agent-svc -n $NAMESPACE"

# 3. Check PostgreSQL connectivity from MCP server pod
echo ""
echo "--- Database Connectivity ---"
MCP_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=mcp-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$MCP_POD" ]; then
    check "MCP server can resolve postgres-svc DNS" \
        "oc exec $MCP_POD -n $NAMESPACE -- node -e \"require('dns').lookup('postgres-svc', (e,a) => { if(e) process.exit(1); console.log(a); process.exit(0); })\""
fi

# 4. Check MCP server health from agent pod
echo ""
echo "--- MCP Server Health ---"
AGENT_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$AGENT_POD" ]; then
    check "Agent can reach MCP server health endpoint" \
        "oc exec $AGENT_POD -n $NAMESPACE -- python -c \"import httpx; r = httpx.get('http://mcp-server-svc:3000/health'); assert r.status_code == 200\""
fi

# 5. Check agent health via route
echo ""
echo "--- Agent Route ---"
ROUTE_URL=$(oc get route agent-route -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "")

if [ -n "$ROUTE_URL" ]; then
    check "Agent route responds (HTTPS)" \
        "curl -sk https://$ROUTE_URL/health | grep -q healthy"
else
    echo "  [Route not found - skipping external access test]"
fi

# 6. Check architecture
echo ""
echo "--- Architecture Verification ---"
PG_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

if [ -n "$PG_POD" ]; then
    check "PostgreSQL running on ppc64le" \
        "oc exec $PG_POD -n $NAMESPACE -- uname -m | grep -q ppc64le"
fi

if [ -n "$MCP_POD" ]; then
    check "MCP Server running on ppc64le" \
        "oc exec $MCP_POD -n $NAMESPACE -- uname -m | grep -q ppc64le"
fi

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ $FAIL -gt 0 ]; then
    exit 1
fi
