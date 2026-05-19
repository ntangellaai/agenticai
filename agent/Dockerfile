# Agent Dockerfile - Multi-stage for minimal image size
# All pip dependencies are pure Python - no native compilation needed

# Stage 1: Install dependencies in full Python image
FROM registry.redhat.io/ubi9/python-311:latest AS builder

USER 0
WORKDIR /opt/app-root

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir --target=/deps -r requirements.txt && \
    find /deps -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true && \
    find /deps -type d -name 'tests' -exec rm -rf {} + 2>/dev/null || true && \
    find /deps -name '*.pyc' -delete 2>/dev/null || true

# Stage 2: Minimal runtime
FROM registry.redhat.io/ubi9/ubi-minimal:latest

LABEL name="agenticai-agent" \
      version="1.0.0" \
      description="Enterprise AI Agent for PostgreSQL MCP Demo" \
      io.k8s.description="Agentic AI assistant with MCP tool calling" \
      io.k8s.display-name="Enterprise AI Agent" \
      io.openshift.tags="ai,agent,mcp,llm"

# Install only Python runtime (no pip, no dev tools) ~40MB
RUN microdnf install -y python3.11 --nodocs && \
    microdnf clean all && \
    rm -rf /var/cache/dnf

WORKDIR /opt/app-root/src

# Copy installed packages from builder
COPY --from=builder /deps /opt/app-root/deps

# Copy application source only
COPY src/ ./

USER 1001

EXPOSE 8080

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONPATH=/opt/app-root/deps
ENV AGENT_PORT=8080

CMD ["python3.11", "-m", "gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "--timeout", "120", "main:app"]
