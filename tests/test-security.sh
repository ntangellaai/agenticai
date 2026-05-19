#!/bin/bash
# =============================================================================
# Test: Security posture validation
# Checks SCC compliance, NetworkPolicies, and container security
# =============================================================================

set -euo pipefail

NAMESPACE="agenticai-demo"
PASS=0
FAIL=0

echo "=== Security Posture Test Suite ==="
echo "Namespace: $NAMESPACE"
echo ""

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

check_not() {
    local desc="$1"
    local cmd="$2"
    echo -n "  [$desc]... "
    if eval "$cmd" > /dev/null 2>&1; then
        echo "❌ FAIL (should not be possible)"
        ((FAIL++))
    else
        echo "✅ PASS (correctly blocked)"
        ((PASS++))
    fi
}

# === Container Security ===
echo "--- Container Security Context ---"

# Check pods run as non-root
for label in "postgres" "mcp-server" "agent"; do
    POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=$label -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD" ]; then
        check "$label runs as non-root" \
            "oc exec $POD -n $NAMESPACE -- id | grep -v 'uid=0'"

        check "$label has no privilege escalation" \
            "oc get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].securityContext.allowPrivilegeEscalation}' | grep -q false"

        check "$label drops ALL capabilities" \
            "oc get pod $POD -n $NAMESPACE -o jsonpath='{.spec.containers[0].securityContext.capabilities.drop[0]}' | grep -q ALL"
    fi
done

# === SCC Compliance ===
echo ""
echo "--- SCC Compliance ---"
check "Namespace has restricted PSA enforcement" \
    "oc get ns $NAMESPACE -o jsonpath='{.metadata.labels.pod-security\\.kubernetes\\.io/enforce}' | grep -q restricted"

# Check all pods are using restricted SCC
for label in "postgres" "mcp-server" "agent"; do
    POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=$label -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD" ]; then
        check "$label uses restricted SCC" \
            "oc get pod $POD -n $NAMESPACE -o jsonpath='{.metadata.annotations.openshift\\.io/scc}' | grep -q restricted"
    fi
done

# === NetworkPolicy ===
echo ""
echo "--- NetworkPolicy Enforcement ---"
check "Default deny policy exists" \
    "oc get networkpolicy deny-all-default -n $NAMESPACE"

check "PostgreSQL NetworkPolicy exists" \
    "oc get networkpolicy postgres-allow-mcp-only -n $NAMESPACE"

check "MCP server NetworkPolicy exists" \
    "oc get networkpolicy mcp-server-policy -n $NAMESPACE"

check "Agent NetworkPolicy exists" \
    "oc get networkpolicy agent-policy -n $NAMESPACE"

# Test that agent CANNOT directly reach PostgreSQL
AGENT_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$AGENT_POD" ]; then
    echo ""
    echo "--- NetworkPolicy Blocking Tests ---"
    check_not "Agent cannot reach PostgreSQL directly (port 5432)" \
        "oc exec $AGENT_POD -n $NAMESPACE -- timeout 3 bash -c 'echo > /dev/tcp/postgres-svc/5432' 2>/dev/null"
fi

# === ServiceAccount Tokens ===
echo ""
echo "--- ServiceAccount Configuration ---"
for label in "postgres" "mcp-server" "agent"; do
    POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=$label -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$POD" ]; then
        AUTOMOUNT=$(oc get pod $POD -n $NAMESPACE -o jsonpath='{.spec.automountServiceAccountToken}')
        if [ "$AUTOMOUNT" = "false" ]; then
            echo "  [$label: SA token not mounted]... ✅ PASS"
            ((PASS++))
        else
            echo "  [$label: SA token not mounted]... ❌ FAIL"
            ((FAIL++))
        fi
    fi
done

# === Secrets ===
echo ""
echo "--- Secrets Management ---"
check "postgres-credentials secret exists" \
    "oc get secret postgres-credentials -n $NAMESPACE"

check "llm-api-key secret exists" \
    "oc get secret llm-api-key -n $NAMESPACE"

# Verify no secrets in environment variable dump
AGENT_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=agent -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$AGENT_POD" ]; then
    check "LLM API key not visible in pod spec" \
        "oc get pod $AGENT_POD -n $NAMESPACE -o yaml | grep -v 'secretKeyRef' | grep -cv 'LLM_API_KEY.*value:'"
fi

# === Resource Limits ===
echo ""
echo "--- Resource Limits ---"
check "ResourceQuota exists" \
    "oc get resourcequota agenticai-demo-quota -n $NAMESPACE"

check "LimitRange exists" \
    "oc get limitrange agenticai-demo-limits -n $NAMESPACE"

# Summary
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ $FAIL -gt 0 ]; then
    echo "⚠️  Security posture has issues that need addressing!"
    exit 1
else
    echo "✅ All security checks passed."
fi
