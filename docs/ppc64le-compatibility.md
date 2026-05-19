# ppc64le Compatibility Checklist

## Overview

IBM Power Systems use the `ppc64le` (PowerPC 64-bit Little Endian) architecture. Not all container images are built for this architecture. This document tracks compatibility for every component.

## Verification Commands

### Check if an image supports ppc64le

```bash
# Check manifest list for multi-arch support
skopeo inspect --raw docker://registry.redhat.io/rhel9/postgresql-16 | jq '.manifests[].platform'

# Expected output should include:
# {
#   "architecture": "ppc64le",
#   "os": "linux"
# }

# For Docker Hub images:
skopeo inspect --raw docker://docker.io/library/node:20-slim | jq '.manifests[].platform'

# For specific architecture:
skopeo inspect --override-arch ppc64le docker://registry.redhat.io/rhel9/postgresql-16
```

### Verify a running container's architecture
```bash
oc exec <pod-name> -- uname -m
# Expected: ppc64le
```

---

## Component Compatibility Matrix

### PostgreSQL 16

| Item | Value |
|------|-------|
| **Image** | `registry.redhat.io/rhel9/postgresql-16` |
| **ppc64le** | ✅ Verified — Red Hat ships multi-arch UBI images |
| **Alternative** | `registry.redhat.io/rhel8/postgresql-16` |
| **Fallback** | Build from `ubi9-minimal` + dnf install postgresql-server |
| **Verification** | `skopeo inspect --raw docker://registry.redhat.io/rhel9/postgresql-16 \| jq '.manifests[].platform'` |

**Notes:**
- Red Hat UBI/RHEL images are reliably multi-arch (amd64, arm64, ppc64le, s390x)
- The image runs as non-root by default (UID 26 for postgres user)
- OpenShift's `restricted` SCC is compatible

### Node.js 20 (for MCP Server)

| Item | Value |
|------|-------|
| **Image** | `registry.redhat.io/ubi9/nodejs-20` |
| **ppc64le** | ✅ Verified — UBI Node.js images are multi-arch |
| **Alternative** | `registry.access.redhat.com/ubi9/nodejs-20-minimal` |
| **Docker Hub** | `docker.io/library/node:20-slim` — ✅ multi-arch including ppc64le |
| **Verification** | `skopeo inspect --raw docker://registry.redhat.io/ubi9/nodejs-20 \| jq '.manifests[].platform'` |

**Notes:**
- Pure JavaScript/TypeScript packages work fine on ppc64le
- Native npm modules (node-gyp) may fail — avoid if possible
- `pg` (node-postgres) is pure JS — ✅ safe
- `@modelcontextprotocol/sdk` is pure TypeScript — ✅ safe
- Avoid: `better-sqlite3`, `canvas`, `sharp` (native binaries)

### Python 3.11 (for Agent)

| Item | Value |
|------|-------|
| **Image** | `registry.redhat.io/ubi9/python-311` |
| **ppc64le** | ✅ Verified — UBI Python images are multi-arch |
| **Alternative** | `registry.access.redhat.com/ubi9/python-311-minimal` |
| **Verification** | `skopeo inspect --raw docker://registry.redhat.io/ubi9/python-311 \| jq '.manifests[].platform'` |

**Notes:**
- Pure Python packages: ✅ always work
- Packages with C extensions need wheels or compilation:
  - `psycopg2-binary` — ⚠️ may not have ppc64le wheel; use `psycopg2` with `libpq-devel`
  - `numpy` — ✅ has ppc64le wheels on recent versions
  - `pydantic` — ✅ pure Python core; Rust extension optional
  - `httpx` — ✅ pure Python
  - `langchain` — ✅ pure Python
  - `openai` — ✅ pure Python
- **Avoid on ppc64le:**
  - `chromadb` (depends on `hnswlib` C++ extension — no ppc64le wheel)
  - `faiss-cpu` (no ppc64le wheel)
  - `tokenizers` (Rust-based — may need cargo build)
  - `torch` / `pytorch` (no official ppc64le pip wheel)

### Go (Alternative for MCP Server or Agent)

| Item | Value |
|------|-------|
| **Compiler** | Go 1.21+ supports ppc64le natively |
| **ppc64le** | ✅ First-class GOARCH=ppc64le support |
| **Base image** | `registry.redhat.io/ubi9/go-toolset` for building |
| **Runtime** | `registry.access.redhat.com/ubi9-micro` (scratch-like) |

**Notes:**
- Go cross-compiles trivially: `GOOS=linux GOARCH=ppc64le go build`
- Static binaries can run on `ubi9-micro` or `scratch`
- Best option if Python dependencies are problematic
- No native extension issues

### LLM Server (llama.cpp on Power10)

| Item | Value |
|------|-------|
| **Software** | `llama.cpp` compiled for ppc64le with Power10 optimizations |
| **ppc64le** | ✅ Builds natively on Power10 — uses VSX/MMA SIMD extensions |
| **Namespace** | `llm` (service: `llm-svc`, port: 8080) |
| **API** | OpenAI-compatible `/v1/chat/completions` with tool/function calling |
| **Model format** | GGUF quantised models (Q4_K_M, Q5_K_M, Q6_K recommended) |

**Notes:**
- llama.cpp builds cleanly on ppc64le with `make LLAMA_NATIVE=1` (enables Power10 MMA instructions)
- Tool/function calling requires `--jinja` flag or a model with built-in tool support (e.g., Granite, Llama 3.1+, Mistral)
- Inference is CPU-bound on Power10; typical latency 5-30s for complex responses — agent timeout set to 120s
- Recommended: run with `--n-gpu-layers 0 --threads $(nproc)` to maximize Power10 CPU cores
- Memory: quantised 8B models need ~6-8GB RAM; 70B models need ~40-48GB RAM (Q4_K_M)

### Streamlit (UI)

| Item | Value |
|------|-------|
| **Package** | `streamlit` |
| **ppc64le** | ⚠️ Depends on `pyarrow` which needs ppc64le wheel or build |
| **Fallback** | Use Flask + simple HTML/JS frontend instead |
| **Alternative** | Gradio (similar dependency profile) |

**Notes:**
- If `pyarrow` wheel is unavailable, build from source (slow, needs Arrow C++ libs)
- Safer alternative: plain Flask/FastAPI with HTML template
- Or: serve a static React/Vue frontend from Nginx

---

## Recommended Base Images

| Use Case | Image | Registry |
|----------|-------|----------|
| PostgreSQL | `rhel9/postgresql-16` | registry.redhat.io |
| Node.js runtime | `ubi9/nodejs-20-minimal` | registry.redhat.io |
| Python runtime | `ubi9/python-311` | registry.redhat.io |
| Go build | `ubi9/go-toolset` | registry.redhat.io |
| Minimal runtime | `ubi9-micro` | registry.access.redhat.com |
| General UBI | `ubi9/ubi-minimal` | registry.redhat.io |

---

## Things to Avoid on ppc64le

| Component | Reason |
|-----------|--------|
| ChromaDB | hnswlib C++ extension has no ppc64le wheel |
| FAISS | No ppc64le pip wheel |
| PyTorch (pip) | No official ppc64le wheel; use IBM PowerAI conda channel or build |
| sharp (npm) | Native image library; no ppc64le prebuilt |
| better-sqlite3 | Native binding; needs compile |
| Electron-based tools | No ppc64le builds |
| Docker Hub "latest" tags | Often amd64-only; always verify |
| Bitnami images | Often amd64-only; prefer Red Hat UBI |

---

## Validation Script

Save as `scripts/validate-images.sh`:

```bash
#!/bin/bash
set -euo pipefail

IMAGES=(
  "registry.redhat.io/rhel9/postgresql-16"
  "registry.redhat.io/ubi9/nodejs-20"
  "registry.redhat.io/ubi9/python-311"
  "registry.access.redhat.com/ubi9-micro"
)

echo "=== ppc64le Image Compatibility Check ==="
for img in "${IMAGES[@]}"; do
  echo ""
  echo "Checking: $img"
  ARCHS=$(skopeo inspect --raw "docker://$img" 2>/dev/null | jq -r '.manifests[].platform.architecture' 2>/dev/null || echo "SINGLE_ARCH")
  if echo "$ARCHS" | grep -q "ppc64le"; then
    echo "  ✅ ppc64le supported"
  elif [ "$ARCHS" = "SINGLE_ARCH" ]; then
    ARCH=$(skopeo inspect "docker://$img" 2>/dev/null | jq -r '.Architecture' 2>/dev/null || echo "UNKNOWN")
    if [ "$ARCH" = "ppc64le" ]; then
      echo "  ✅ ppc64le (single-arch image)"
    else
      echo "  ❌ Only $ARCH available"
    fi
  else
    echo "  ❌ ppc64le NOT found. Available: $ARCHS"
  fi
done
```

---

## NPM Package Compatibility (MCP Server)

| Package | Native? | ppc64le Safe? |
|---------|---------|---------------|
| `@modelcontextprotocol/sdk` | No (pure TS) | ✅ |
| `pg` (node-postgres) | No (pure JS) | ✅ |
| `zod` | No (pure TS) | ✅ |
| `express` | No (pure JS) | ✅ |
| `dotenv` | No (pure JS) | ✅ |
| `typescript` | No (pure JS) | ✅ |

---

## Python Package Compatibility (Agent)

| Package | Native? | ppc64le Safe? | Notes |
|---------|---------|---------------|-------|
| `langchain` | No | ✅ | Pure Python |
| `langchain-openai` | No | ✅ | Pure Python |
| `openai` | No | ✅ | Pure Python |
| `httpx` | No | ✅ | Pure Python |
| `pydantic` | Optional Rust | ✅ | Falls back to pure Python |
| `psycopg2` | Yes (C) | ⚠️ | Need `libpq-devel` in image |
| `asyncpg` | Yes (C) | ⚠️ | Compiles from source, usually works |
| `mcp` | No | ✅ | Pure Python MCP SDK |
| `flask` | No | ✅ | Pure Python |
| `gunicorn` | No | ✅ | Pure Python |

---

## Build-from-Source Strategy

When a pre-built image or package isn't available for ppc64le:

1. **Use UBI base image** — already has ppc64le tools
2. **Multi-stage build** — compile in `ubi9/go-toolset` or `ubi9/nodejs-20`, copy to `ubi9-micro`
3. **Install build deps** — `dnf install -y gcc python3-devel libpq-devel`
4. **Test locally** — use `podman build --platform linux/ppc64le` if you have qemu-user-static

```bash
# Enable cross-platform builds with podman
sudo dnf install qemu-user-static
podman build --platform linux/ppc64le -t my-mcp-server:ppc64le .
```

---

## Key Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| npm native module fails | MCP server won't start | Use only pure JS/TS packages |
| Python wheel missing | Agent build fails | Pin versions; use UBI with dev tools |
| Base image not multi-arch | Pod fails to schedule | Verify all images with skopeo before deploy |
| LLM endpoint unavailable | Agent cannot answer | Mock LLM for testing; clear error handling |
| OpenShift SCC rejection | Pod won't start | Test with `oc adm policy who-can use scc restricted` |
