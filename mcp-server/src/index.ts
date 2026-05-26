import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { z } from "zod";
import pg from "pg";
import express from "express";

const { Pool } = pg;

// =============================================================================
// Configuration
// =============================================================================

const CONFIG = {
  port: parseInt(process.env.MCP_SERVER_PORT || "3000"),
  db: {
    host: process.env.PGHOST || "localhost",
    port: parseInt(process.env.PGPORT || "5432"),
    database: process.env.PGDATABASE || "enterprise_contracts",
    user: process.env.PGUSER || "mcp_readonly",
    password: process.env.PGPASSWORD || "",
    max: 5,
    idleTimeoutMillis: 60000,
    connectionTimeoutMillis: 10000,
    statement_timeout: 30000,
  },
  security: {
    maxRows: 1000,
    blockedKeywords: [
      "INSERT",
      "UPDATE",
      "DELETE",
      "DROP",
      "ALTER",
      "CREATE",
      "TRUNCATE",
      "GRANT",
      "REVOKE",
      "COPY",
      "EXECUTE",
      "DO ",
      "CALL ",
      "SET ",
      "RESET ",
      "LOAD ",
      "LOCK ",
      "VACUUM",
      "REINDEX",
      "CLUSTER",
      "COMMENT",
      "SECURITY",
    ],
    allowedPrefixes: ["SELECT", "WITH"],
  },
};

// =============================================================================
// Database Pool
// =============================================================================

const pool = new Pool(CONFIG.db);

pool.on("error", (err) => {
  console.error("Unexpected database pool error:", err.message);
});

// =============================================================================
// SQL Validation (Defence in Depth)
// =============================================================================

function validateSQL(sql: string): { valid: boolean; reason?: string } {
  const trimmed = sql.trim();

  if (!trimmed) {
    return { valid: false, reason: "Empty query" };
  }

  if (trimmed.length > 5000) {
    return { valid: false, reason: "Query too long (max 5000 characters)" };
  }

  const normalized = trimmed.toUpperCase();

  // Must start with allowed prefix
  const startsValid = CONFIG.security.allowedPrefixes.some((prefix) =>
    normalized.startsWith(prefix)
  );
  if (!startsValid) {
    return {
      valid: false,
      reason: "Query must start with SELECT or WITH",
    };
  }

  // Check for blocked keywords
  for (const keyword of CONFIG.security.blockedKeywords) {
    // Use word boundary-like check to avoid false positives
    const regex = new RegExp(`\\b${keyword.trim()}\\b`, "i");
    if (regex.test(trimmed)) {
      return {
        valid: false,
        reason: `Blocked keyword detected: ${keyword.trim()}`,
      };
    }
  }

  // Block multiple statements (semicolons not at end)
  const withoutStrings = trimmed.replace(/'[^']*'/g, "");
  const semicolons = (withoutStrings.match(/;/g) || []).length;
  if (semicolons > 1) {
    return { valid: false, reason: "Multiple statements not allowed" };
  }

  return { valid: true };
}

// =============================================================================
// Query Execution
// =============================================================================

async function executeQuery(
  sql: string
): Promise<{ columns: string[]; rows: Record<string, unknown>[]; rowCount: number }> {
  const validation = validateSQL(sql);
  if (!validation.valid) {
    throw new Error(`SQL validation failed: ${validation.reason}`);
  }

  // Add LIMIT if not present
  const normalized = sql.trim().toUpperCase();
  let safeSql = sql.trim();
  if (!normalized.includes("LIMIT")) {
    safeSql = `${safeSql.replace(/;?\s*$/, "")} LIMIT ${CONFIG.security.maxRows}`;
  }

  const client = await pool.connect();
  try {
    // Set statement timeout for this query
    await client.query("SET statement_timeout = '30s'");
    const result = await client.query(safeSql);

    const columns = result.fields.map((f) => f.name);
    return {
      columns,
      rows: result.rows,
      rowCount: result.rowCount || 0,
    };
  } finally {
    client.release();
  }
}

// =============================================================================
// Table Metadata
// =============================================================================

// Dynamic schema discovery - no hardcoded table list

// =============================================================================
// MCP Server Setup
// =============================================================================

const server = new McpServer({
  name: "enterprise-postgres-mcp",
  version: "1.0.0",
});

// Tool: query
server.tool(
  "query",
  "Execute a read-only SQL query against the enterprise contracts database. Only SELECT statements are allowed.",
  {
    sql: z
      .string()
      .describe(
        "SQL SELECT query to execute. Must be read-only. Maximum 1000 rows returned."
      ),
  },
  async ({ sql }) => {
    try {
      const result = await executeQuery(sql);
      const text = JSON.stringify(
        {
          columns: result.columns,
          rows: result.rows,
          rowCount: result.rowCount,
          truncated: result.rowCount >= CONFIG.security.maxRows,
        },
        null,
        2
      );
      return { content: [{ type: "text", text }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      return {
        content: [{ type: "text", text: `Error: ${message}` }],
        isError: true,
      };
    }
  }
);

// Tool: list_tables
server.tool(
  "list_tables",
  "List all available tables and views in the database with their types",
  {},
  async () => {
    try {
      const result = await executeQuery(`
        SELECT table_name, table_type
        FROM information_schema.tables
        WHERE table_schema = 'public'
        ORDER BY table_type, table_name
      `);
      const text = JSON.stringify(result.rows, null, 2);
      return { content: [{ type: "text", text }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      return {
        content: [{ type: "text", text: `Error: ${message}` }],
        isError: true,
      };
    }
  }
);

// Tool: describe_table
server.tool(
  "describe_table",
  "Get column names, data types, and constraints for a specific table or view",
  {
    table: z
      .string()
      .describe("Name of the table or view to describe"),
  },
  async ({ table }) => {
    // Validate table name to prevent injection
    if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(table)) {
      return {
        content: [{ type: "text", text: "Error: Invalid table name" }],
        isError: true,
      };
    }

    try {
      const result = await executeQuery(`
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = '${table}'
        ORDER BY ordinal_position
      `);

      if (result.rowCount === 0) {
        return {
          content: [
            {
              type: "text",
              text: `Error: Table '${table}' not found. Use list_tables to see available tables.`,
            },
          ],
          isError: true,
        };
      }

      const text = JSON.stringify(
        {
          table,
          columns: result.rows,
        },
        null,
        2
      );
      return { content: [{ type: "text", text }] };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      return {
        content: [{ type: "text", text: `Error: ${message}` }],
        isError: true,
      };
    }
  }
);

// =============================================================================
// HTTP Server with SSE Transport
// =============================================================================

const app = express();

// Health check endpoint
app.get("/health", async (_req, res) => {
  try {
    const client = await pool.connect();
    await client.query("SELECT 1");
    client.release();
    res.json({ status: "healthy", database: "connected" });
  } catch {
    res.status(503).json({ status: "unhealthy", database: "disconnected" });
  }
});

// SSE endpoint for MCP
const transports: Map<string, SSEServerTransport> = new Map();

app.get("/sse", async (req, res) => {
  console.log("New SSE connection established");
  const transport = new SSEServerTransport("/messages", res);
  transports.set(transport.sessionId, transport);

  res.on("close", () => {
    transports.delete(transport.sessionId);
    console.log("SSE connection closed");
  });

  await server.connect(transport);
});

app.post("/messages", async (req, res) => {
  const sessionId = req.query.sessionId as string;
  const transport = transports.get(sessionId);
  if (!transport) {
    res.status(404).json({ error: "Session not found" });
    return;
  }
  await transport.handlePostMessage(req, res);
});

// Start server
app.listen(CONFIG.port, "0.0.0.0", () => {
  console.log(`MCP Server listening on port ${CONFIG.port}`);
  console.log(`Database: ${CONFIG.db.host}:${CONFIG.db.port}/${CONFIG.db.database}`);
  console.log(`User: ${CONFIG.db.user} (read-only)`);
  console.log(`Max rows per query: ${CONFIG.security.maxRows}`);
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  console.log("SIGTERM received, shutting down...");
  await pool.end();
  process.exit(0);
});

process.on("SIGINT", async () => {
  console.log("SIGINT received, shutting down...");
  await pool.end();
  process.exit(0);
});
