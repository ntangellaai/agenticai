# Architecture Overview

## System Context

This demo deploys an Agentic AI system on Red Hat OpenShift running on IBM Power Systems (ppc64le). The agent answers business questions by autonomously querying enterprise data in PostgreSQL via the Model Context Protocol (MCP).

## Component Roles

### 1. PostgreSQL 16 (Data Layer)
- **Role:** Stores enterprise contract, customer, spend, and operational data
- **Deployment:** StatefulSet with PVC for persistence
- **Image:** `registry.redhat.io/rhel9/postgresql-16` (ppc64le verified)
- **Security:** Two database users — admin (for setup) and `mcp_readonly` (for runtime queries)
- **Network:** Only accessible from MCP server pod (NetworkPolicy enforced)

### 2. PostgreSQL MCP Server (Tool Layer)
- **Role:** Exposes PostgreSQL as MCP tools that an AI agent can call
- **Protocol:** MCP over HTTP/SSE (Server-Sent Events) for OpenShift deployment
- **Implementation:** Node.js TypeScript server using `@modelcontextprotocol/sdk`
- **Security:** Connects to PostgreSQL with read-only credentials; exposes only `query` tool with SELECT restriction
- **Network:** Only accessible from agent pod

### 3. Agent Orchestrator (Intelligence Layer)
- **Role:** Receives user questions, reasons about what data is needed, calls MCP tools, synthesises answers
- **Implementation:** Python with lightweight custom agent loop using OpenAI-compatible client
- **LLM:** Calls local LLM server deployed in `llm` namespace within the same OpenShift cluster
- **Security:** Cannot write to database; rate-limited; validates tool responses

### 4. LLM Server (Cluster-Local, namespace: `llm`)
- **Role:** Provides language model inference (e.g., Granite, Llama 3.1, Mixtral)
- **Deployment:** llama.cpp compiled for IBM Power10 (ppc64le, MMA/VSX optimized), running in namespace `llm`, service `llm-server` on port 8000
- **Interface:** OpenAI-compatible `/v1/chat/completions` API with tool/function calling support
- **Security:** Cluster-internal only; accessed via service DNS (`llm-server.llm.svc.cluster.local:8000`); NetworkPolicy restricts access
- **Performance:** CPU-only inference on Power10; 120s timeout configured in agent for complex multi-tool queries

### 5. User Interface (Presentation Layer)
- **Role:** Chat interface for business users to ask questions
- **Implementation:** Streamlit (simple) or static HTML+JS with WebSocket
- **Security:** Exposed via OpenShift Route with TLS; optional OAuth proxy

## Data Flow

```
User Question
     │
     ▼
┌─────────────┐
│  Agent UI   │  (OpenShift Route, TLS, optional OAuth)
└──────┬──────┘
       │ HTTP POST /ask
       ▼
┌─────────────────┐
│ Agent Orchestr. │  Receives question, builds prompt
└──────┬──────────┘
       │
       ├──────────────────────────────────┐
       │ 1. Send prompt to LLM            │ 2. LLM responds with tool_call
       ▼                                  │
┌──────────────┐                          │
│ LLM Endpoint │ ◀────────────────────────┘
└──────────────┘
       │
       │ tool_call: mcp_query(sql="SELECT ...")
       ▼
┌─────────────────┐
│ Agent Orchestr. │  Validates SQL (read-only check)
└──────┬──────────┘
       │ MCP tool call
       ▼
┌──────────────────┐
│ PostgreSQL MCP   │  Executes validated query
│     Server       │
└──────┬───────────┘
       │ pg wire protocol
       ▼
┌──────────────────┐
│   PostgreSQL     │  Returns result rows
└──────────────────┘
       │
       │ Results bubble back up
       ▼
┌─────────────────┐
│ Agent Orchestr. │  Formats results, sends to LLM for synthesis
└──────┬──────────┘
       │
       ▼
┌──────────────┐
│ LLM Endpoint │  Generates business-language answer
└──────┬───────┘
       │
       ▼
┌─────────────┐
│  Agent UI   │  Displays answer to user
└─────────────┘
```

## Multi-Turn Behaviour

The agent may perform multiple tool calls in sequence:
1. First query: Get overview data (e.g., total contract values by year)
2. Second query: Drill into specific anomaly (e.g., contracts with >20% increase)
3. Third query: Get context (e.g., contract events for those contracts)
4. Synthesis: Combine all results into a coherent business answer

## MCP Protocol Details

### Transport: HTTP + SSE
- Agent connects to MCP server via HTTP
- Server streams responses via Server-Sent Events
- Suitable for Kubernetes service-to-service communication

### Tools Exposed
| Tool Name | Description | Parameters |
|-----------|-------------|------------|
| `query` | Execute read-only SQL against enterprise database | `sql: string` |
| `list_tables` | List available tables and their descriptions | none |
| `describe_table` | Get column names, types, and descriptions for a table | `table: string` |

### Resources Exposed (Optional)
| Resource | Description |
|----------|-------------|
| `schema://enterprise` | Full schema documentation |
| `data://sample-queries` | Example queries the agent can reference |

## Deployment Topology

```
Namespace: agenticai-demo
├── ServiceAccount: postgres-sa
├── ServiceAccount: mcp-server-sa
├── ServiceAccount: agent-sa
├── StatefulSet: postgres (1 replica)
│   └── PVC: postgres-data (10Gi)
├── Deployment: mcp-server (1-2 replicas)
├── Deployment: agent (1 replica)
├── Service: postgres-svc (ClusterIP, port 5432)
├── Service: mcp-server-svc (ClusterIP, port 3000)
├── Service: agent-svc (ClusterIP, port 8080)
├── Route: agent-route (edge TLS)
├── NetworkPolicy: postgres-allow-mcp-only
├── NetworkPolicy: mcp-allow-agent-only
├── NetworkPolicy: deny-all-default
├── ResourceQuota: demo-quota
├── LimitRange: demo-limits
├── Secret: postgres-credentials
├── Secret: llm-api-key
├── ConfigMap: postgres-init-sql
└── ConfigMap: mcp-server-config
```

## Design Decisions

| Decision | Rationale |
|----------|-----------|
| StatefulSet for PostgreSQL | Stable network identity, ordered deployment, PVC binding |
| Node.js for MCP server | Official MCP SDK is TypeScript; minimal runtime; builds on ppc64le |
| SSE transport for MCP | Works over HTTP; no WebSocket complexity; OpenShift Route compatible |
| Read-only DB user | Defence in depth; even if agent is compromised, data cannot be mutated |
| NetworkPolicies | Zero-trust networking; components only talk to what they need |
| Cluster-local LLM | Uses existing LLM in `llm` namespace; avoids external API dependency; low-latency inference |
| UBI base images | Red Hat supported; ppc64le available; OpenShift compatible |

## Scaling Considerations

- **PostgreSQL:** Single replica for demo; could use Crunchy PGO for production
- **MCP Server:** Stateless; can scale horizontally
- **Agent:** Stateless per request; scale with load
- **LLM:** Deployed in `llm` namespace; scaling is independent of agent

## Network Diagram

```
Internet
    │
    │ HTTPS (TLS terminated at Route)
    ▼
┌─────────────────────────────────────────────┐
│ OpenShift Router (HAProxy)                  │
└────────────────────┬────────────────────────┘
                     │ port 8080
                     ▼
              ┌──────────────┐
              │   Agent Pod  │
              └──────┬───────┘
                     │ port 3000 (ClusterIP)
                     ▼
              ┌──────────────┐
              │  MCP Server  │
              └──────┬───────┘
                     │ port 5432 (ClusterIP)
                     ▼
              ┌──────────────┐
              │  PostgreSQL  │
              └──────────────┘

Agent Pod ─── port 8000 ──▶ llm-server.llm.svc.cluster.local (namespace: llm)
```
