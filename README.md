# Agentic AI Enterprise Demo — OpenShift on IBM Power (ppc64le)

An enterprise-grade demonstration of Agentic AI querying business data via PostgreSQL MCP Server, deployed on Red Hat OpenShift running on IBM Power Systems (ppc64le).

## Overview

This demo shows how an AI assistant can autonomously query enterprise contract, customer, and operational data from PostgreSQL using the Model Context Protocol (MCP), then explain trends, risks, and insights in business language.

**Target Platform:** OpenShift 4.x on IBM Power Systems (ppc64le)

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenShift Cluster (ppc64le)                   │
│                                                                     │
│  ┌─────────────┐    ┌──────────────────┐    ┌──────────────────┐   │
│  │   Agent UI   │───▶│  Agent Orchestr. │───▶│   LLM Server     │   │
│  │  (Route/TLS) │    │  (Python)        │    │  (ns: llm)       │   │
│  └─────────────┘    └────────┬─────────┘    └──────────────────┘   │
│                              │                                       │
│                              │ MCP (stdio/SSE)                       │
│                              ▼                                       │
│                     ┌──────────────────┐                            │
│                     │  PostgreSQL MCP   │                            │
│                     │     Server        │                            │
│                     │  (Node.js/Go)     │                            │
│                     └────────┬─────────┘                            │
│                              │                                       │
│                              │ pg connection (TLS)                    │
│                              ▼                                       │
│                     ┌──────────────────┐                            │
│                     │   PostgreSQL 16   │                            │
│                     │  (StatefulSet)    │                            │
│                     │  PVC: 10Gi        │                            │
│                     └──────────────────┘                            │
│                                                                     │
│  Security: NetworkPolicies │ Restricted SCC │ Non-root │ Secrets    │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Technology | ppc64le Status |
|-----------|-----------|----------------|
| PostgreSQL | PostgreSQL 16 (Red Hat UBI image) | ✅ Verified |
| MCP Server | Node.js (@modelcontextprotocol/server-postgres) or Go custom | ⚠️ Build from source |
| Agent Orchestrator | Python (langchain/langgraph) or Go | ✅ With UBI base |
| LLM Server | Local (namespace: `llm`, service: `llm-server:8000`) | Cluster-internal |
| UI | Streamlit or static HTML + JS | ✅ With UBI base |

## Project Structure

```
agenticai/
├── docs/
│   ├── architecture.md
│   ├── security-design.md
│   ├── ppc64le-compatibility.md
│   └── troubleshooting.md
├── database/
│   ├── schema.sql
│   ├── seed-data.sql
│   ├── views.sql
│   ├── roles.sql
│   └── indexes.sql
├── mcp-server/
│   ├── Dockerfile
│   ├── package.json
│   ├── src/
│   │   └── index.ts
│   └── mcp-config.json
├── agent/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── src/
│       ├── main.py
│       ├── agent.py
│       └── mcp_client.py
├── openshift/
│   ├── namespace.yaml
│   ├── postgres/
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   ├── pvc.yaml
│   │   ├── secret.yaml
│   │   ├── configmap.yaml
│   │   └── networkpolicy.yaml
│   ├── mcp-server/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── configmap.yaml
│   │   └── networkpolicy.yaml
│   ├── agent/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── route.yaml
│   │   └── networkpolicy.yaml
│   ├── serviceaccounts.yaml
│   ├── resourcequota.yaml
│   └── limitrange.yaml
├── tests/
│   ├── test-connectivity.sh
│   ├── test-readonly.sh
│   ├── test-mcp.sh
│   └── test-security.sh
├── scripts/
│   ├── deploy.sh
│   ├── validate-images.sh
│   └── generate-secrets.sh
└── demo-scenarios/
    └── scenarios.md
```

## Quick Start

```bash
# Phase 1: Deploy PostgreSQL
oc apply -f openshift/namespace.yaml
oc apply -f openshift/postgres/

# Phase 2: Load schema and data
oc exec -it postgres-0 -- psql -U postgres -f /docker-entrypoint-initdb.d/schema.sql

# Phase 3: Deploy MCP Server
oc apply -f openshift/mcp-server/

# Phase 4: Deploy Agent
oc apply -f openshift/agent/

# Phase 5: Validate
./tests/test-connectivity.sh
./tests/test-readonly.sh
```

## Security Highlights

- All containers run as non-root (UID 1001+)
- Restricted SCC enforced
- NetworkPolicies isolate all components
- PostgreSQL MCP user is read-only
- Secrets managed via OpenShift Secrets (not hardcoded)
- TLS on all external routes
- SQL queries restricted to SELECT only
- Prompt injection mitigations in agent layer

## License

Internal demo — not for redistribution.
