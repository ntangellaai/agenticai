"""
MCP Client - Connects to the PostgreSQL MCP Server via HTTP/SSE.
Lightweight implementation using httpx for SSE transport.
"""

import json
import logging
import uuid
from typing import Any
import httpx

logger = logging.getLogger("agent.mcp_client")


class MCPClient:
    """Client for communicating with an MCP server over HTTP/SSE."""

    def __init__(self, server_url: str, timeout: float = 30.0):
        self.server_url = server_url.rstrip("/")
        self.timeout = timeout
        self.session_id: str | None = None
        self._http = httpx.Client(timeout=timeout)

    def _ensure_session(self) -> None:
        """Establish SSE session if not already connected."""
        if self.session_id:
            return

        # Connect to SSE endpoint to get session ID
        try:
            with self._http.stream("GET", f"{self.server_url}/sse") as response:
                for line in response.iter_lines():
                    if line.startswith("data:"):
                        # Parse session endpoint
                        data = line[5:].strip()
                        if "sessionId=" in data:
                            self.session_id = data.split("sessionId=")[1].split("&")[0]
                            logger.info(f"MCP session established: {self.session_id}")
                            return
        except Exception as e:
            logger.warning(f"SSE session setup failed: {e}")
            # Fallback: try direct HTTP mode
            self.session_id = "direct"

    def call_tool(self, tool_name: str, arguments: dict[str, Any]) -> str:
        """
        Call an MCP tool and return the result as a string.
        
        Falls back to direct HTTP POST if SSE session fails.
        """
        # Try direct HTTP call (simpler for service-to-service)
        try:
            response = self._http.post(
                f"{self.server_url}/messages",
                params={"sessionId": self.session_id or "default"},
                json={
                    "jsonrpc": "2.0",
                    "id": str(uuid.uuid4()),
                    "method": "tools/call",
                    "params": {
                        "name": tool_name,
                        "arguments": arguments,
                    },
                },
                headers={"Content-Type": "application/json"},
            )

            if response.status_code == 404 and not self.session_id:
                # Need to establish session first
                self._ensure_session()
                return self.call_tool(tool_name, arguments)

            if response.status_code != 200:
                return json.dumps({
                    "error": f"MCP server returned {response.status_code}: {response.text[:200]}"
                })

            result = response.json()

            if "error" in result:
                return json.dumps({"error": result["error"].get("message", "Unknown MCP error")})

            # Extract content from MCP response
            content = result.get("result", {}).get("content", [])
            if content and len(content) > 0:
                return content[0].get("text", json.dumps(content))

            return json.dumps(result.get("result", {}))

        except httpx.TimeoutException:
            logger.error(f"MCP tool call timed out: {tool_name}")
            return json.dumps({"error": "Tool call timed out"})
        except Exception as e:
            logger.error(f"MCP tool call failed: {tool_name} - {e}")
            return json.dumps({"error": f"Tool call failed: {str(e)}"})

    def health_check(self) -> bool:
        """Check if MCP server is healthy."""
        try:
            response = self._http.get(f"{self.server_url}/health")
            return response.status_code == 200
        except Exception:
            return False

    def close(self) -> None:
        """Close the HTTP client."""
        self._http.close()
