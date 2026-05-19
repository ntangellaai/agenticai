#!/bin/bash
# =============================================================================
# Deployment Script - Agentic AI Demo on OpenShift (ppc64le)
# Phased deployment with validation at each step
# =============================================================================

set -euo pipefail

NAMESPACE="agenticai-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "  Agentic AI Demo - OpenShift Deployment"
echo "  Platform: IBM Power (ppc64le)"
echo "============================================"
echo ""

# Check prerequisites
echo "--- Checking Prerequisites ---"
command -v oc >/dev/null 2>&1 || { echo "ERROR: oc CLI not found"; exit 1; }
oc whoami > /dev/null 2>&1 || { echo "ERROR: Not logged in to OpenShift. Run 'oc login' first."; exit 1; }
echo "  Logged in as: $(oc whoami)"
echo "  Cluster: $(oc whoami --show-server)"
echo ""

# =============================================================================
# Phase 1: Namespace and RBAC
# =============================================================================
echo "=== Phase 1: Namespace and RBAC ==="

echo "  Creating namespace..."
oc apply -f "$PROJECT_DIR/openshift/namespace.yaml"

echo "  Creating service accounts..."
oc apply -f "$PROJECT_DIR/openshift/serviceaccounts.yaml"

echo "  Creating resource quota..."
oc apply -f "$PROJECT_DIR/openshift/resourcequota.yaml"

echo "  Creating limit range..."
oc apply -f "$PROJECT_DIR/openshift/limitrange.yaml"

echo "  ✅ Phase 1 complete"
echo ""

# =============================================================================
# Phase 2: Secrets (generate random passwords)
# =============================================================================
echo "=== Phase 2: Secrets ==="

# Check if secrets already exist
if oc get secret postgres-credentials -n $NAMESPACE > /dev/null 2>&1; then
    echo "  postgres-credentials already exists, skipping..."
else
    echo "  Generating PostgreSQL credentials..."
    # Alphanumeric only — no special chars that break connection strings
    ADMIN_PW=$(openssl rand -hex 16)
    APP_PW=$(openssl rand -hex 16)
    MCP_PW=$(openssl rand -hex 16)

    oc create secret generic postgres-credentials \
        --from-literal=POSTGRESQL_ADMIN_PASSWORD="$ADMIN_PW" \
        --from-literal=POSTGRESQL_USER="appuser" \
        --from-literal=POSTGRESQL_PASSWORD="$APP_PW" \
        --from-literal=POSTGRESQL_DATABASE="enterprise_contracts" \
        --from-literal=MCP_READONLY_USER="mcp_readonly" \
        --from-literal=MCP_READONLY_PASSWORD="$MCP_PW" \
        -n $NAMESPACE
    echo "  ✅ postgres-credentials created (passwords auto-generated)"
fi

if oc get secret llm-api-key -n $NAMESPACE > /dev/null 2>&1; then
    echo "  llm-api-key already exists, skipping..."
else
    echo "  Creating llm-api-key secret (local LLM in 'llm' namespace)..."
    oc create secret generic llm-api-key \
        --from-literal=LLM_API_KEY="not-required" \
        --from-literal=LLM_ENDPOINT="http://llm-svc.llm.svc.cluster.local:8080/v1" \
        -n $NAMESPACE
fi

echo "  ✅ Phase 2 complete"
echo ""

# =============================================================================
# Phase 3: PostgreSQL
# =============================================================================
echo "=== Phase 3: PostgreSQL ==="

echo "  Applying PostgreSQL ConfigMap..."
oc apply -f "$PROJECT_DIR/openshift/postgres/configmap.yaml"

echo "  Applying PostgreSQL PVC..."
oc apply -f "$PROJECT_DIR/openshift/postgres/pvc.yaml"

echo "  Applying PostgreSQL StatefulSet..."
oc apply -f "$PROJECT_DIR/openshift/postgres/statefulset.yaml"

echo "  Applying PostgreSQL Service..."
oc apply -f "$PROJECT_DIR/openshift/postgres/service.yaml"

echo "  Applying PostgreSQL NetworkPolicy..."
oc apply -f "$PROJECT_DIR/openshift/postgres/networkpolicy.yaml"

echo "  Waiting for PostgreSQL pod to be ready..."
oc wait --for=condition=ready pod -l app.kubernetes.io/name=postgres -n $NAMESPACE --timeout=180s

echo "  ✅ Phase 3 complete - PostgreSQL is running"
echo ""

# =============================================================================
# Phase 4: Load Schema and Data
# =============================================================================
echo "=== Phase 4: Schema and Data ==="

PG_POD=$(oc get pod -n $NAMESPACE -l app.kubernetes.io/name=postgres -o jsonpath='{.items[0].metadata.name}')

echo "  Loading schema..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/schema.sql"

echo "  Loading Batch 1: Reference data (managers + providers)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-1-reference.sql"

echo "  Loading Batch 2: Customers (~200 records)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-2-customers.sql"

echo "  Loading Batch 3: Contracts (~2000 records)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-3-contracts.sql"

echo "  Loading Batch 4: Contract Events (~3000-6000 records)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-4-events.sql"

echo "  Loading Batch 5: Spend History (~8000-12000 records)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-5-spend.sql"

echo "  Loading Batch 6: Support Tickets (~2000 records)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-6-tickets.sql"

echo "  Loading Batch 7: Renewal Risks + Documents (~1000 records)..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/seed-data-batch-7-risks-docs.sql"

echo "  Creating views..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/views.sql"

echo "  Creating indexes..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts < "$PROJECT_DIR/database/indexes.sql"

echo "  Setting up read-only user..."
# Get the MCP password from secret
MCP_READONLY_PW=$(oc get secret postgres-credentials -n $NAMESPACE -o jsonpath='{.data.MCP_READONLY_PASSWORD}' | base64 -d)
oc exec $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts -c "
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readonly') THEN
        EXECUTE format('CREATE ROLE mcp_readonly WITH LOGIN PASSWORD %L', '$MCP_READONLY_PW');
    ELSE
        EXECUTE format('ALTER ROLE mcp_readonly WITH PASSWORD %L', '$MCP_READONLY_PW');
    END IF;
END
\$\$;
GRANT CONNECT ON DATABASE enterprise_contracts TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO mcp_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM mcp_readonly;
ALTER ROLE mcp_readonly CONNECTION LIMIT 5;
ALTER ROLE mcp_readonly SET statement_timeout = '30s';
"

echo "  Validating data load..."
oc exec -i $PG_POD -n $NAMESPACE -- psql -U postgres -d enterprise_contracts -c "
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
) t ORDER BY row_count DESC;
"

echo "  ✅ Phase 4 complete - Schema and data loaded"
echo ""

# =============================================================================
# Phase 5: MCP Server
# =============================================================================
echo "=== Phase 5: MCP Server ==="

echo "  Applying MCP server ConfigMap..."
oc apply -f "$PROJECT_DIR/openshift/mcp-server/configmap.yaml"

echo "  Building MCP server image (binary build)..."
if ! oc get bc mcp-server -n $NAMESPACE > /dev/null 2>&1; then
    oc new-build --binary --name=mcp-server --strategy=docker -n $NAMESPACE
fi
oc start-build mcp-server --from-dir="$PROJECT_DIR/mcp-server/" -n $NAMESPACE --follow

echo "  Applying MCP server Deployment..."
oc apply -f "$PROJECT_DIR/openshift/mcp-server/deployment.yaml"

echo "  Applying MCP server Service..."
oc apply -f "$PROJECT_DIR/openshift/mcp-server/service.yaml"

echo "  Applying MCP server NetworkPolicy..."
oc apply -f "$PROJECT_DIR/openshift/mcp-server/networkpolicy.yaml"

echo "  Waiting for MCP server pod to be ready..."
oc rollout status deployment/mcp-server -n $NAMESPACE --timeout=180s

echo "  ✅ Phase 5 complete - MCP Server running"
echo ""

# =============================================================================
# Phase 6: Agent
# =============================================================================
echo "=== Phase 6: Agent ==="

echo "  Building agent image (binary build)..."
if ! oc get bc agent -n $NAMESPACE > /dev/null 2>&1; then
    oc new-build --binary --name=agent --strategy=docker -n $NAMESPACE
fi
oc start-build agent --from-dir="$PROJECT_DIR/agent/" -n $NAMESPACE --follow

echo "  Applying Agent Deployment..."
oc apply -f "$PROJECT_DIR/openshift/agent/deployment.yaml"

echo "  Applying Agent Service..."
oc apply -f "$PROJECT_DIR/openshift/agent/service.yaml"

echo "  Applying Agent Route..."
oc apply -f "$PROJECT_DIR/openshift/agent/route.yaml"

echo "  Applying Agent NetworkPolicy..."
oc apply -f "$PROJECT_DIR/openshift/agent/networkpolicy.yaml"

echo "  Waiting for Agent pod to be ready..."
oc rollout status deployment/agent -n $NAMESPACE --timeout=180s

echo "  ✅ Phase 6 complete - Agent running"
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "============================================"
echo "  Deployment Complete!"
echo "============================================"
echo ""
echo "  Namespace: $NAMESPACE"
echo ""

echo "  Pod status:"
oc get pods -n $NAMESPACE -o wide
echo ""

ROUTE_URL=$(oc get route agent-route -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "NOT YET AVAILABLE")
echo "  Agent URL: https://$ROUTE_URL"
echo ""
echo "  Quick verification:"
echo "    curl -s https://$ROUTE_URL/health"
echo ""
echo "  Run tests:"
echo "    $PROJECT_DIR/tests/test-connectivity.sh"
echo ""
