# Multi-stage build for MCP Server
# Base: Red Hat UBI Node.js 20 (verified ppc64le)
# All npm dependencies are pure JS/TS - no native modules

# Stage 1: Build
FROM registry.redhat.io/ubi9/nodejs-20:latest AS builder

USER 0
WORKDIR /opt/app-root/src

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./
RUN npm ci --production=false

# Copy source and build
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Remove dev dependencies
RUN npm prune --production

# Stage 2: Production runtime
FROM registry.redhat.io/ubi9/nodejs-20-minimal:latest

LABEL name="enterprise-postgres-mcp" \
      version="1.0.0" \
      description="PostgreSQL MCP Server for Agentic AI Demo" \
      io.k8s.description="MCP server exposing PostgreSQL as AI tools" \
      io.k8s.display-name="PostgreSQL MCP Server" \
      io.openshift.tags="mcp,postgresql,ai"

WORKDIR /opt/app-root/src

# Copy built application
COPY --from=builder /opt/app-root/src/dist ./dist
COPY --from=builder /opt/app-root/src/node_modules ./node_modules
COPY --from=builder /opt/app-root/src/package.json ./

# Non-root user (UBI images default to 1001)
USER 1001

# Expose MCP server port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://localhost:3000/health').then(r => r.ok ? process.exit(0) : process.exit(1)).catch(() => process.exit(1))"

ENV NODE_ENV=production
ENV MCP_SERVER_PORT=3000

CMD ["node", "dist/index.js"]
