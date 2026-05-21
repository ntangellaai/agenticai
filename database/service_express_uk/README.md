# Service Express UK Database

Anonymised contract data for UK Cloud services.

## Schema
- `schema.sql` - Database schema (tables, views, indexes)
- `data.sql` - Anonymised data for April 2026 (337 contracts)

## Deployment

```bash
# On bastion
cd /root/agenticai

# Create database (if not exists)
oc exec -n agenticai-demo postgres-0 -- psql -U postgres -c "CREATE DATABASE service_express_uk;"

# Apply schema
oc exec -i -n agenticai-demo postgres-0 -- psql -U postgres -d service_express_uk < database/service_express_uk/schema.sql

# Load data
oc exec -i -n agenticai-demo postgres-0 -- psql -U postgres -d service_express_uk < database/service_express_uk/data.sql

# Grant MCP access
oc exec -n agenticai-demo postgres-0 -- psql -U postgres -d service_express_uk -c "GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;"
oc exec -n agenticai-demo postgres-0 -- psql -U postgres -d service_express_uk -c "GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO mcp_readonly;"
```
