# Security Design

## Principles

1. **Least privilege** — every component has minimal permissions
2. **Defence in depth** — multiple layers protect data
3. **Zero trust networking** — deny all, allow explicit paths only
4. **Immutable infrastructure** — read-only filesystems where possible
5. **No hardcoded secrets** — all credentials via OpenShift Secrets
6. **Audit trail** — log all queries and access

---

## OpenShift Security

### Namespace Isolation

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: agenticai-demo
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/audit: restricted
```

The namespace enforces the `restricted` Pod Security Standard, which requires:
- Non-root containers
- No privilege escalation
- Drop ALL capabilities
- Seccomp profile set

### Security Context (All Pods)

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1001
  fsGroup: 1001
  seccompProfile:
    type: RuntimeDefault
containers:
  - securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
          - ALL
```

### ServiceAccounts

| ServiceAccount | Used By | Permissions |
|---------------|---------|-------------|
| `postgres-sa` | PostgreSQL StatefulSet | None (default) |
| `mcp-server-sa` | MCP Server Deployment | None (default) |
| `agent-sa` | Agent Deployment | None (default) |

No ServiceAccount needs cluster-level RBAC. All operate within namespace only.

```yaml
automountServiceAccountToken: false  # Set on all pods
```

### SCC Compliance (OpenShift restricted)

All containers comply with OpenShift's `restricted` SCC:
- UID range assigned by namespace
- No `hostNetwork`, `hostPID`, `hostIPC`
- No `privileged` containers
- No host path volumes
- fsGroup set from namespace annotation

---

## Network Security

### Default Deny Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-default
  namespace: agenticai-demo
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
```

### Allowed Network Paths

| From | To | Port | Protocol |
|------|----|------|----------|
| Agent | MCP Server | 3000 | TCP |
| MCP Server | PostgreSQL | 5432 | TCP |
| Agent | LLM Server (llm namespace) | 8000 | TCP (cross-namespace) |
| OpenShift Router | Agent | 8080 | TCP |
| Agent | DNS | 53 | UDP (egress) |
| MCP Server | DNS | 53 | UDP (egress) |

### What is Blocked

- ❌ UI/Agent cannot reach PostgreSQL directly
- ❌ MCP Server cannot reach the internet
- ❌ PostgreSQL cannot reach anything
- ❌ No pod-to-pod communication except explicit policies
- ❌ No external ingress except via OpenShift Route to Agent

---

## PostgreSQL Security

### Users and Roles

```sql
-- Admin user (used only for schema setup, not at runtime)
CREATE ROLE pg_admin WITH LOGIN PASSWORD '<generated>' CREATEDB;

-- Read-only user for MCP server (runtime)
CREATE ROLE mcp_readonly WITH LOGIN PASSWORD '<generated>';
GRANT CONNECT ON DATABASE enterprise_contracts TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;

-- Explicitly deny write operations
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM mcp_readonly;
```

### Connection Security

- **pg_hba.conf:** Require `scram-sha-256` authentication
- **SSL:** Enable `ssl = on` in postgresql.conf (self-signed cert for internal)
- **Connection limit:** `ALTER ROLE mcp_readonly CONNECTION LIMIT 5;`
- **Statement timeout:** `ALTER ROLE mcp_readonly SET statement_timeout = '30s';`

### Query Restrictions

Applied at multiple layers:

1. **Database layer:** User has SELECT-only grants
2. **MCP server layer:** Validates SQL starts with SELECT/WITH (whitelist)
3. **Agent layer:** System prompt instructs read-only; validates before sending
4. **Statement timeout:** 30 seconds max query time

### Audit Logging

```sql
-- Enable in postgresql.conf
log_statement = 'all'
log_connections = on
log_disconnections = on
log_line_prefix = '%t [%p] %u@%d '
```

---

## MCP Server Security

### Tool Restrictions

Only expose safe, read-only tools:

```typescript
const ALLOWED_TOOLS = ['query', 'list_tables', 'describe_table'];

// SQL validation before execution
function validateSQL(sql: string): boolean {
  const normalized = sql.trim().toUpperCase();
  // Must start with SELECT or WITH (CTE)
  if (!normalized.startsWith('SELECT') && !normalized.startsWith('WITH')) {
    return false;
  }
  // Block dangerous keywords even in subqueries
  const blocked = ['INSERT', 'UPDATE', 'DELETE', 'DROP', 'ALTER', 'CREATE',
                   'TRUNCATE', 'GRANT', 'REVOKE', 'COPY', 'EXECUTE',
                   'DO ', 'CALL '];
  for (const kw of blocked) {
    if (normalized.includes(kw)) return false;
  }
  return true;
}
```

### Row Limit

All queries wrapped with `LIMIT 1000` if no limit specified, preventing data exfiltration of entire tables.

### No Dynamic Schema Changes

MCP server does not expose tools for DDL operations. Schema is fixed at deploy time.

---

## Agent Security

### System Prompt Boundaries

```
You are a business analyst AI. You can ONLY read data.
You must NEVER attempt to:
- Modify, delete, or insert data
- Run DDL statements
- Access system tables (pg_catalog, information_schema)
- Exfiltrate full table contents
- Execute commands outside the provided MCP tools

If a user asks you to modify data, politely decline and explain you are read-only.
```

### Prompt Injection Mitigations

1. **Input sanitisation:** Strip control characters, limit input length (2000 chars)
2. **Tool call validation:** Agent validates SQL before sending to MCP
3. **Output filtering:** Remove any SQL or code from final response if not requested
4. **Separate system/user contexts:** System prompt is not modifiable by user input
5. **Rate limiting:** Max 10 tool calls per question; max 5 questions per minute

### LLM Access Control

- LLM server is cluster-internal in namespace `llm` (service: `llm-server`, port 8000)
- No external API key required; access controlled via NetworkPolicy
- Agent egress restricted to `llm` namespace pods with label `app: llm-server`
- No sensitive credentials to leak or rotate

---

## TLS Configuration

### External (Route)

```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: agent-route
spec:
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
  to:
    kind: Service
    name: agent-svc
```

### Internal (PostgreSQL)

- PostgreSQL configured with `ssl = on`
- Self-signed certificate generated at deploy time
- MCP server connects with `sslmode=require`
- Certificate mounted from Secret

---

## Secrets Management

| Secret | Contents | Used By |
|--------|----------|---------|
| `postgres-credentials` | `POSTGRES_PASSWORD`, `MCP_READONLY_PASSWORD` | PostgreSQL, MCP Server |
| `llm-api-key` | `LLM_API_KEY`, `LLM_ENDPOINT` | Agent |

### Generation

```bash
# Generate random passwords
MCP_PW=$(openssl rand -base64 24)
ADMIN_PW=$(openssl rand -base64 24)

oc create secret generic postgres-credentials \
  --from-literal=POSTGRES_PASSWORD="$ADMIN_PW" \
  --from-literal=MCP_READONLY_PASSWORD="$MCP_PW" \
  -n agenticai-demo

oc create secret generic llm-api-key \
  --from-literal=LLM_API_KEY="not-required" \
  --from-literal=LLM_ENDPOINT="http://llm-server.llm.svc.cluster.local:8000/v1" \
  -n agenticai-demo
```

---

## Resource Limits

Prevent resource exhaustion and noisy-neighbour issues:

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: demo-quota
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    persistentvolumeclaims: "2"
    pods: "10"
```

---

## OAuth Proxy (Optional)

For enterprise auth on the Agent UI:

```yaml
# Add oauth-proxy sidecar to agent deployment
- name: oauth-proxy
  image: registry.redhat.io/openshift4/ose-oauth-proxy
  args:
    - --upstream=http://localhost:8080
    - --cookie-secret=<generated>
    - --openshift-service-account=agent-sa
    - --https-address=:8443
  ports:
    - containerPort: 8443
```

This integrates with OpenShift's built-in OAuth server for SSO.

---

## Security Checklist

- [ ] All pods run as non-root
- [ ] All pods drop ALL capabilities
- [ ] readOnlyRootFilesystem on all containers (with emptyDir for /tmp)
- [ ] NetworkPolicies deployed and tested
- [ ] PostgreSQL user is SELECT-only
- [ ] SQL validation in MCP server
- [ ] Secrets not hardcoded anywhere
- [ ] TLS on external route
- [ ] Resource quotas set
- [ ] Service account tokens not auto-mounted
- [ ] No cluster-admin RBAC
- [ ] Prompt injection tested
- [ ] Rate limits configured
- [ ] Statement timeout on DB user
- [ ] Audit logging enabled
