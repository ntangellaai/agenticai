#!/bin/bash
# =============================================================================
# Generate OpenShift Secrets for Agentic AI Demo
# Run this ONCE before deployment to create secure credentials
# =============================================================================

set -euo pipefail

NAMESPACE="${1:-agenticai-demo}"

echo "=== Secret Generation for $NAMESPACE ==="
echo ""

# Check if namespace exists
if ! oc get namespace $NAMESPACE > /dev/null 2>&1; then
    echo "ERROR: Namespace '$NAMESPACE' does not exist. Create it first."
    echo "  oc apply -f openshift/namespace.yaml"
    exit 1
fi

# Generate random passwords (alphanumeric only, no special chars)
ADMIN_PW=$(openssl rand -hex 16)
APP_PW=$(openssl rand -hex 16)
MCP_PW=$(openssl rand -hex 16)

echo "--- PostgreSQL Credentials ---"
if oc get secret postgres-credentials -n $NAMESPACE > /dev/null 2>&1; then
    echo "  ⚠️  Secret 'postgres-credentials' already exists."
    read -p "  Overwrite? (y/N): " CONFIRM
    if [ "$CONFIRM" != "y" ]; then
        echo "  Skipping postgres-credentials."
    else
        oc delete secret postgres-credentials -n $NAMESPACE
        oc create secret generic postgres-credentials \
            --from-literal=POSTGRESQL_ADMIN_PASSWORD="$ADMIN_PW" \
            --from-literal=POSTGRESQL_USER="appuser" \
            --from-literal=POSTGRESQL_PASSWORD="$APP_PW" \
            --from-literal=POSTGRESQL_DATABASE="enterprise_contracts" \
            --from-literal=MCP_READONLY_USER="mcp_readonly" \
            --from-literal=MCP_READONLY_PASSWORD="$MCP_PW" \
            -n $NAMESPACE
        echo "  ✅ postgres-credentials created"
    fi
else
    oc create secret generic postgres-credentials \
        --from-literal=POSTGRESQL_ADMIN_PASSWORD="$ADMIN_PW" \
        --from-literal=POSTGRESQL_USER="appuser" \
        --from-literal=POSTGRESQL_PASSWORD="$APP_PW" \
        --from-literal=POSTGRESQL_DATABASE="enterprise_contracts" \
        --from-literal=MCP_READONLY_USER="mcp_readonly" \
        --from-literal=MCP_READONLY_PASSWORD="$MCP_PW" \
        -n $NAMESPACE
    echo "  ✅ postgres-credentials created"
fi

echo ""
echo "--- LLM Configuration ---"
echo "  Using local LLM server in namespace 'llm' (service: llm-svc)"
echo "  Endpoint: http://llm-svc.llm.svc.cluster.local:8080/v1"
echo "  No API key required for local LLM."
echo ""
if oc get secret llm-api-key -n $NAMESPACE > /dev/null 2>&1; then
    echo "  Secret 'llm-api-key' already exists. Skipping."
    echo "  To update: oc delete secret llm-api-key -n $NAMESPACE && re-run this script"
else
    oc create secret generic llm-api-key \
        --from-literal=LLM_API_KEY="not-required" \
        --from-literal=LLM_ENDPOINT="http://llm-svc.llm.svc.cluster.local:8080/v1" \
        -n $NAMESPACE
    echo "  ✅ llm-api-key created (local LLM)"
fi

echo ""
echo "=== Done ==="
echo ""
echo "Secrets created in namespace: $NAMESPACE"
echo "  - postgres-credentials"
echo "  - llm-api-key"
echo ""
echo "⚠️  Passwords are NOT displayed. To retrieve:"
echo "  oc get secret postgres-credentials -n $NAMESPACE -o jsonpath='{.data.MCP_READONLY_PASSWORD}' | base64 -d"
