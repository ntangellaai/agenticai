#!/bin/bash
# =============================================================================
# FALLBACK: Build images on bastion and push to OpenShift internal registry.
#
# Use this ONLY if in-cluster builds fail (e.g. build pods can't reach internet).
# In normal deployments, deploy.sh handles builds via oc start-build with the
# global pull secret copied into the namespace.
#
# Requirements on bastion:
#   - podman installed
#   - oc CLI logged in
#   - Internet access to registry.redhat.io
#
# Usage: ./scripts/mirror-images.sh [registry-route]
#
# Example:
#   ./scripts/mirror-images.sh default-route-openshift-image-registry.apps.demo-0847.miscplatform.io
# =============================================================================

set -euo pipefail

ROUTE="${1:-default-route-openshift-image-registry.apps.demo-0847.miscplatform.io}"
NAMESPACE="agenticai-demo"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "============================================"
echo "  Build & Push Images to Internal Registry"
echo "  Registry: $ROUTE"
echo "  Namespace: $NAMESPACE"
echo "============================================"
echo ""

# Check prerequisites
command -v podman >/dev/null 2>&1 || { echo "ERROR: podman not found"; exit 1; }
command -v oc >/dev/null 2>&1 || { echo "ERROR: oc CLI not found"; exit 1; }
oc whoami > /dev/null 2>&1 || { echo "ERROR: Not logged in to OpenShift. Run 'oc login' first."; exit 1; }

# Ensure namespace exists
oc get namespace "$NAMESPACE" > /dev/null 2>&1 || { echo "ERROR: Namespace '$NAMESPACE' not found. Run deploy.sh first to create it."; exit 1; }

# Log in to the internal registry using the current OCP token
echo "--- Logging into internal registry ---"
TOKEN=$(oc whoami -t)
podman login "$ROUTE" --username "unused" --password "$TOKEN" --tls-verify=false
echo ""

# =============================================================================
# Build and push MCP server
# =============================================================================
echo "=== Building MCP Server ==="
MCP_IMAGE="$ROUTE/$NAMESPACE/mcp-server:latest"

podman build \
    --platform linux/ppc64le \
    --tag "$MCP_IMAGE" \
    "$PROJECT_DIR/mcp-server/"

echo "  Pushing to internal registry..."
podman push "$MCP_IMAGE" --tls-verify=false
echo "  ✅ mcp-server pushed: $MCP_IMAGE"
echo ""

# Create/update the imagestream tag so the deployment can reference it
oc tag "$ROUTE/$NAMESPACE/mcp-server:latest" "mcp-server:latest" -n "$NAMESPACE" --insecure 2>/dev/null || true

# =============================================================================
# Build and push Agent
# =============================================================================
echo "=== Building Agent ==="
AGENT_IMAGE="$ROUTE/$NAMESPACE/agent:latest"

podman build \
    --platform linux/ppc64le \
    --tag "$AGENT_IMAGE" \
    "$PROJECT_DIR/agent/"

echo "  Pushing to internal registry..."
podman push "$AGENT_IMAGE" --tls-verify=false
echo "  ✅ agent pushed: $AGENT_IMAGE"
echo ""

# =============================================================================
# Summary
# =============================================================================
echo "============================================"
echo "  Images built and pushed:"
echo "  mcp-server: image-registry.openshift-image-registry.svc:5000/$NAMESPACE/mcp-server:latest"
echo "  agent:      image-registry.openshift-image-registry.svc:5000/$NAMESPACE/agent:latest"
echo "============================================"
echo ""
echo "  Next: run ./scripts/deploy.sh"
