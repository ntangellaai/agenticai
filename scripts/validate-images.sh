#!/bin/bash
# =============================================================================
# Validate container image ppc64le compatibility
# Checks all images used in this project for ppc64le architecture support
# =============================================================================

set -euo pipefail

echo "=== ppc64le Image Compatibility Checker ==="
echo ""

IMAGES=(
    "registry.redhat.io/rhel9/postgresql-16"
    "registry.redhat.io/ubi9/nodejs-20"
    "registry.redhat.io/ubi9/nodejs-20-minimal"
    "registry.redhat.io/ubi9/python-311"
    "registry.access.redhat.com/ubi9-micro"
)

PASS=0
FAIL=0

for img in "${IMAGES[@]}"; do
    echo -n "  Checking: $img ... "
    
    # Try to get manifest list
    RESULT=$(skopeo inspect --raw "docker://$img" 2>/dev/null || echo "ERROR")
    
    if [ "$RESULT" = "ERROR" ]; then
        echo "❌ CANNOT INSPECT (check registry auth)"
        ((FAIL++))
        continue
    fi
    
    # Check if it's a manifest list (multi-arch)
    MEDIA_TYPE=$(echo "$RESULT" | jq -r '.mediaType // .schemaVersion' 2>/dev/null || echo "")
    
    if echo "$MEDIA_TYPE" | grep -q "manifest.list\|image.index"; then
        # Multi-arch image - check for ppc64le
        ARCHS=$(echo "$RESULT" | jq -r '.manifests[].platform.architecture' 2>/dev/null)
        if echo "$ARCHS" | grep -q "ppc64le"; then
            echo "✅ ppc64le (multi-arch)"
            ((PASS++))
        else
            echo "❌ NO ppc64le (available: $(echo $ARCHS | tr '\n' ', '))"
            ((FAIL++))
        fi
    else
        # Single arch image - check which one
        ARCH=$(skopeo inspect "docker://$img" 2>/dev/null | jq -r '.Architecture' 2>/dev/null || echo "unknown")
        if [ "$ARCH" = "ppc64le" ]; then
            echo "✅ ppc64le (single-arch)"
            ((PASS++))
        else
            echo "❌ Single arch: $ARCH"
            ((FAIL++))
        fi
    fi
done

echo ""
echo "=== Results: $PASS supported, $FAIL not supported ==="
echo ""

if [ $FAIL -gt 0 ]; then
    echo "⚠️  Some images do not support ppc64le. You may need to:"
    echo "  - Use alternative images"
    echo "  - Build from source using a ppc64le UBI base"
    echo "  - Check registry authentication (podman login registry.redhat.io)"
    exit 1
else
    echo "✅ All images support ppc64le architecture."
fi

echo ""
echo "--- Additional Checks ---"
echo ""
echo "To verify a specific image manually:"
echo '  skopeo inspect --raw docker://IMAGE | jq ".manifests[].platform"'
echo ""
echo "To pull a specific architecture:"
echo '  podman pull --platform linux/ppc64le IMAGE'
echo ""
echo "To check what architecture a running container uses:"
echo '  oc exec POD -- uname -m'
