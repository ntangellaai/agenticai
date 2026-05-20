# Multi-stage build for MCP Server
# Base: Red Hat UBI Node.js 20 (verified ppc64le)
# All npm dependencies are pure JS/TS - no native modules

# Stage 1: Build
FROM registry.redhat.io/ubi9/nodejs-20:latest AS builder

USER 0
WORKDIR /opt/app-root/src

# Copy package files first for better layer caching
COPY package.json package-lock.json* ./
RUN npm install && npm cache clean --force

# Copy source and build
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Install only production dependencies in a clean directory
RUN mkdir /prod && cp package.json /prod/ && \
    cd /prod && npm install --omit=dev && npm cache clean --force && \
    rm -rf /root/.npm

# Stage 2: Production runtime (minimal image ~60MB base)
FROM registry.redhat.io/ubi9/nodejs-20-minimal:latest

LABEL name="enterprise-postgres-mcp" \
      version="1.0.0" \
      description="PostgreSQL MCP Server for Agentic AI Demo" \
      io.k8s.description="MCP server exposing PostgreSQL as AI tools" \
      io.k8s.display-name="PostgreSQL MCP Server" \
      io.openshift.tags="mcp,postgresql,ai"

WORKDIR /opt/app-root/src

# Copy only compiled JS and production node_modules
COPY --from=builder /opt/app-root/src/dist ./dist
COPY --from=builder /prod/node_modules ./node_modules
COPY --from=builder /opt/app-root/src/package.json ./

USER 1001

EXPOSE 3000

ENV NODE_ENV=production
ENV MCP_SERVER_PORT=3000

CMD ["node", "dist/index.js"]
