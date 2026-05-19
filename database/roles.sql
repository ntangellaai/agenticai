-- =============================================================================
-- PostgreSQL Roles and Permissions
-- Run as superuser/admin after schema creation
-- =============================================================================

-- Read-only role for MCP server
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'mcp_readonly') THEN
        CREATE ROLE mcp_readonly WITH LOGIN PASSWORD 'CHANGE_ME_VIA_SECRET';
    END IF;
END
$$;

-- Grant minimal permissions
GRANT CONNECT ON DATABASE enterprise_contracts TO mcp_readonly;
GRANT USAGE ON SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO mcp_readonly;
GRANT SELECT ON ALL SEQUENCES IN SCHEMA public TO mcp_readonly;

-- Ensure future tables are also readable
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO mcp_readonly;

-- Explicitly revoke write permissions
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM mcp_readonly;
REVOKE CREATE ON SCHEMA public FROM mcp_readonly;

-- Connection and statement limits
ALTER ROLE mcp_readonly CONNECTION LIMIT 5;
ALTER ROLE mcp_readonly SET statement_timeout = '30s';
ALTER ROLE mcp_readonly SET lock_timeout = '5s';
ALTER ROLE mcp_readonly SET idle_in_transaction_session_timeout = '60s';

-- Prevent access to system catalogs (optional, defense in depth)
-- Note: pg_catalog access is needed for basic operations, but we can restrict
-- information_schema is generally safe to read
REVOKE ALL ON SCHEMA pg_catalog FROM mcp_readonly;
GRANT USAGE ON SCHEMA pg_catalog TO mcp_readonly;

-- Verify permissions
-- Run as mcp_readonly to test:
-- SET ROLE mcp_readonly;
-- SELECT * FROM customers LIMIT 1;  -- Should work
-- INSERT INTO customers (customer_name, segment, industry, region, onboarded_date) VALUES ('Test', 'SMB', 'Tech', 'EMEA', '2024-01-01');  -- Should fail
-- DROP TABLE customers;  -- Should fail
