# Agent Dockerfile
# Base: Red Hat UBI Python 3.11 (verified ppc64le)
# All pip dependencies are pure Python - no native compilation needed

FROM registry.redhat.io/ubi9/python-311:latest

LABEL name="agenticai-agent" \
      version="1.0.0" \
      description="Enterprise AI Agent for PostgreSQL MCP Demo" \
      io.k8s.description="Agentic AI assistant with MCP tool calling" \
      io.k8s.display-name="Enterprise AI Agent" \
      io.openshift.tags="ai,agent,mcp,llm"

WORKDIR /opt/app-root/src

# Install Python dependencies
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application source
COPY src/ ./

# Non-root user (UBI images default to 1001)
USER 1001

EXPOSE 8080

ENV PYTHONUNBUFFERED=1
ENV AGENT_PORT=8080

# Use gunicorn for production
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "--timeout", "120", "main:app"]
