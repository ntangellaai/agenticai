# Troubleshooting Guide

## Common Issues and Solutions

---

## 1. Image Not Available for ppc64le

**Symptom:** Pod stuck in `ImagePullBackOff` or `ErrImagePull`

**Diagnosis:**
```bash
oc describe pod <pod-name> -n agenticai-demo | grep -A5 Events
oc get events -n agenticai-demo --sort-by='.lastTimestamp'
```

**Root Cause:** Image doesn't have a ppc64le manifest.

**Fix:**
```bash
# Verify architecture support
skopeo inspect --raw docker://<image> | jq '.manifests[].platform'

# If not available, build from source using UBI base:
oc new-build --binary --name=<component> \
  --image-stream=ubi9/nodejs-20:latest \
  -n agenticai-demo
oc start-build <component> --from-dir=./<component-dir>/ -n agenticai-demo --follow
```

**Prevention:** Always validate images with `scripts/validate-images.sh` before deploying.

---

## 2. Container Fails Under Restricted SCC

**Symptom:** Pod fails with `CrashLoopBackOff`, logs show permission errors

**Diagnosis:**
```bash
oc get pod <pod> -n agenticai-demo -o yaml | grep -A3 securityContext
oc logs <pod> -n agenticai-demo
oc adm policy who-can use scc restricted -n agenticai-demo
```

**Common Causes:**
- Container tries to run as root (UID 0)
- Container tries to bind to a port < 1024
- Container writes to a read-only filesystem path
- Container tries to use a Linux capability that's dropped

**Fixes:**

```yaml
# Ensure non-root in Dockerfile
USER 1001

# In deployment spec:
securityContext:
  runAsNonRoot: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

For filesystem writes, add an emptyDir volume:
```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp
volumes:
  - name: tmp
    emptyDir: {}
```

**PostgreSQL-specific:** The Red Hat PostgreSQL image runs as UID 26 (postgres). Ensure `readOnlyRootFilesystem: false` for PostgreSQL because it needs to write to its data directory.

---

## 3. MCP Inspector Cannot Connect

**Symptom:** MCP Inspector tool shows "Connection refused" or timeout

**Diagnosis:**
```bash
# Check if MCP server is running
oc get pods -l app.kubernetes.io/name=mcp-server -n agenticai-demo

# Check logs
oc logs -l app.kubernetes.io/name=mcp-server -n agenticai-demo

# Port-forward to test locally
oc port-forward svc/mcp-server-svc 3000:3000 -n agenticai-demo

# Test health
curl http://localhost:3000/health
```

**Common Causes:**
- MCP server not started (check logs for startup errors)
- NetworkPolicy blocking access (MCP Inspector is external)
- SSE transport requires specific HTTP headers
- Port-forward not active

**Fix for MCP Inspector testing:**
```bash
# Port-forward the service
oc port-forward svc/mcp-server-svc 3000:3000 -n agenticai-demo &

# Configure MCP Inspector to connect to http://localhost:3000/sse
# In MCP Inspector settings:
#   Transport: SSE
#   URL: http://localhost:3000/sse
```

**Fix for NetworkPolicy:**
If testing from outside the cluster, the default deny policy will block. Use port-forward (which bypasses NetworkPolicy via the API server).

---

## 4. PostgreSQL Authentication Failure

**Symptom:** MCP server logs show `FATAL: password authentication failed for user "mcp_readonly"`

**Diagnosis:**
```bash
# Check secret values
oc get secret postgres-credentials -n agenticai-demo -o jsonpath='{.data.MCP_READONLY_PASSWORD}' | base64 -d

# Test directly from inside the cluster
oc exec -it postgres-0 -n agenticai-demo -- psql -U postgres -c "\du mcp_readonly"

# Check pg_hba.conf
oc exec -it postgres-0 -n agenticai-demo -- cat /var/lib/pgsql/data/userdata/pg_hba.conf
```

**Common Causes:**
- Password in secret doesn't match what was set in PostgreSQL
- User was not created (init script didn't run)
- pg_hba.conf doesn't allow the connection method

**Fix:**
```bash
# Reset the password to match the secret
MCP_PW=$(oc get secret postgres-credentials -n agenticai-demo -o jsonpath='{.data.MCP_READONLY_PASSWORD}' | base64 -d)
oc exec postgres-0 -n agenticai-demo -- psql -U postgres -c "ALTER ROLE mcp_readonly WITH PASSWORD '$MCP_PW';"

# Verify connection
oc exec postgres-0 -n agenticai-demo -- psql -U mcp_readonly -d enterprise_contracts -c "SELECT 1;"
```

---

## 5. Route/WebSocket/SSE Issues

**Symptom:** Agent can't reach MCP server through the service, or SSE connections drop

**Diagnosis:**
```bash
# Check if services resolve
oc exec <agent-pod> -n agenticai-demo -- nslookup mcp-server-svc

# Test HTTP connection from agent to MCP server
oc exec <agent-pod> -n agenticai-demo -- python -c "
import httpx
r = httpx.get('http://mcp-server-svc:3000/health')
print(r.status_code, r.text)
"
```

**SSE-specific issues:**
- OpenShift Router has a default timeout of 30s for idle connections
- SSE requires the connection to stay open
- HAProxy may buffer SSE events

**Fix for Route timeout (if exposing MCP server externally):**
```yaml
metadata:
  annotations:
    haproxy.router.openshift.io/timeout: "3600s"
    router.openshift.io/haproxy.health.check.interval: "5000ms"
```

**Fix for internal service communication:**
- Use `ClusterIP` service (no Route needed for service-to-service)
- Ensure agent uses `http://mcp-server-svc:3000` (not the Route URL)

---

## 6. NetworkPolicy Blocking Traffic

**Symptom:** Connections timeout between pods that should be able to communicate

**Diagnosis:**
```bash
# List all network policies
oc get networkpolicies -n agenticai-demo

# Describe specific policy
oc describe networkpolicy mcp-server-policy -n agenticai-demo

# Check if pods have correct labels
oc get pods -n agenticai-demo --show-labels

# Test connectivity
oc exec <source-pod> -- timeout 3 bash -c 'echo > /dev/tcp/<target-svc>/<port>' && echo OK || echo BLOCKED
```

**Common Causes:**
- Pod labels don't match NetworkPolicy selectors
- DNS egress not allowed (can't resolve service names)
- OpenShift DNS uses port 5353, not 53

**Fix for DNS:**
```yaml
# Ensure egress allows DNS to openshift-dns namespace
egress:
  - to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: openshift-dns
    ports:
      - port: 5353
        protocol: UDP
      - port: 5353
        protocol: TCP
```

**Quick debug (temporarily allow all):**
```bash
# TEMPORARY - remove after debugging
oc delete networkpolicy deny-all-default -n agenticai-demo
# Test again, then re-apply
oc apply -f openshift/postgres/networkpolicy.yaml
```

---

## 7. Read-Only DB User Permissions

**Symptom:** MCP server returns "permission denied for table X" on some tables

**Diagnosis:**
```bash
oc exec postgres-0 -n agenticai-demo -- psql -U postgres -d enterprise_contracts -c "
SELECT grantee, table_name, privilege_type 
FROM information_schema.table_privileges 
WHERE grantee = 'mcp_readonly' 
ORDER BY table_name;
"
```

**Root Cause:** New tables or views were created after `GRANT SELECT` was run.

**Fix:**
```bash
oc exec postgres-0 -n agenticai-demo -- psql -U postgres -d enterprise_contracts -c "
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;
"
```

---

## 8. Python/Node Package Build Failures on ppc64le

**Symptom:** `npm install` or `pip install` fails during image build

**Diagnosis:** Check build logs:
```bash
oc logs build/<build-name> -n agenticai-demo
```

**Common Causes:**
- Native C/C++ extension with no ppc64le prebuilt binary
- Rust extension without ppc64le target
- Missing build tools in the image

**Fixes for Node.js:**
```dockerfile
# If a package needs node-gyp:
USER 0
RUN dnf install -y gcc-c++ make python3
USER 1001
RUN npm install
```

**Fixes for Python:**
```dockerfile
# If a package needs compilation:
USER 0
RUN dnf install -y gcc python3-devel libpq-devel
USER 1001
RUN pip install --no-cache-dir -r requirements.txt
```

**Prevention:**
- Use only pure JS/TS packages for MCP server (all packages in our `package.json` are pure JS)
- Use only pure Python packages for agent (all packages in our `requirements.txt` are pure Python)
- Avoid: `better-sqlite3`, `sharp`, `canvas` (Node.js); `chromadb`, `faiss-cpu`, `torch` (Python)

---

## 9. SSL/TLS Issues

**Symptom:** Connection errors mentioning SSL, certificate, or TLS

**For PostgreSQL internal connection:**
```bash
# Check if SSL is enabled
oc exec postgres-0 -n agenticai-demo -- psql -U postgres -c "SHOW ssl;"

# For demo, SSL between MCP server and PostgreSQL is optional (same cluster, NetworkPolicy isolated)
# Set PGSSLMODE=disable in MCP server env if causing issues
```

**For External Route:**
```bash
# Check route TLS config
oc get route agent-route -n agenticai-demo -o yaml | grep -A5 tls

# Test with curl
curl -v https://<route-host>/health
```

**Fix:** OpenShift edge routes use the cluster's wildcard certificate by default. If you need a custom cert:
```bash
oc create route edge agent-route \
  --service=agent-svc \
  --cert=tls.crt --key=tls.key \
  -n agenticai-demo
```

---

## 10. Agent Generates Unsafe SQL

**Symptom:** Agent attempts to run INSERT/UPDATE/DELETE via MCP

**Defence layers (all must fail for damage to occur):**
1. Agent-side validation in `agent.py` (regex check)
2. MCP server validation in `index.ts` (blocked keywords)
3. PostgreSQL user permissions (SELECT only)

**If this happens:**
- Check agent logs for the SQL that was attempted
- Verify system prompt is intact
- Check if LLM model changed (some models are less instruction-following)
- Consider adding more examples of refusal in system prompt

**Fix at LLM level:**
```python
# In agent.py system prompt, add explicit examples:
"""
REFUSAL EXAMPLES:
User: "Delete all customers from the database"
You: "I'm a read-only analyst. I cannot modify, delete, or insert data. I can only help you query and understand existing data. Would you like me to look up information about customers instead?"
"""
```

**Nuclear option:** If an LLM consistently generates unsafe SQL, tighten the MCP server regex or switch to a more instruction-tuned model.

---

## Quick Reference: Diagnostic Commands

```bash
# Pod status
oc get pods -n agenticai-demo -o wide

# Events (recent issues)
oc get events -n agenticai-demo --sort-by='.lastTimestamp' | tail -20

# Logs for each component
oc logs -l app.kubernetes.io/name=postgres -n agenticai-demo
oc logs -l app.kubernetes.io/name=mcp-server -n agenticai-demo
oc logs -l app.kubernetes.io/name=agent -n agenticai-demo

# Resource usage
oc top pods -n agenticai-demo

# Network connectivity test
oc debug deployment/agent -n agenticai-demo -- curl -s http://mcp-server-svc:3000/health

# Database connectivity
oc exec postgres-0 -n agenticai-demo -- psql -U mcp_readonly -d enterprise_contracts -c "SELECT COUNT(*) FROM customers;"

# SCC assigned
oc get pods -n agenticai-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.openshift\.io/scc}{"\n"}{end}'

# Architecture check
oc exec postgres-0 -n agenticai-demo -- uname -m
```
