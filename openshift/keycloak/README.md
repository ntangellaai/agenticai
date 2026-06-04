# Keycloak Setup for AgenticAI Demo

## Prerequisites
- Red Hat Keycloak Operator installed in `keycloak` namespace

## Deployment Order

### 1. Deploy Keycloak Database
```bash
oc apply -f openshift/keycloak/keycloak-db.yaml
oc -n keycloak rollout status deployment/postgres-db
```

### 2. Deploy Keycloak Instance
```bash
oc apply -f openshift/keycloak/keycloak-instance.yaml
# Wait for Keycloak to become ready (may take 2-3 minutes)
oc -n keycloak get keycloak keycloak -w
```

### 3. Import Demo Realm, Users and Groups
```bash
oc apply -f openshift/keycloak/realm-import.yaml
oc -n keycloak get keycloakrealmimport demo-realm-import -w
```

### 4. Get Keycloak Admin Console URL
```bash
oc -n keycloak get keycloak keycloak -o jsonpath='{.status.conditions}' | python3 -m json.tool
oc -n keycloak get route -l app=keycloak
```

## Realm: `demo`

### Groups
| Group | Purpose |
|---|---|
| `/admins` | Full access |
| `/analysts` | Read/query access |
| `/viewers` | Read-only dashboard access |

### Default Users
| Username | Password | Group |
|---|---|---|
| admin-user | Admin1234! | admins |
| analyst1 | Analyst1234! | analysts |
| viewer1 | Viewer1234! | viewers |

> **Note:** Change all default passwords before exposing externally.

### OIDC Client
- **Client ID:** `agenticai-agent`
- **Client Secret:** Set in `realm-import.yaml` → `changeme-client-secret`
- **Flow:** Authorization Code + PKCE
- **Redirect URI:** Update to match your actual agent route

## Next Steps
Once Keycloak is running, implement OIDC authentication in the agent app (see `feature/keycloak-auth` branch).
