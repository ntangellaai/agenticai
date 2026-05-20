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
        self._sse_response = None

    def _ensure_session(self) -> None:
        """Establish SSE session if not already connected."""
        if self.session_id:
            return

        # Open SSE stream and hold it open; extract sessionId from the first endpoint event
        try:
            self._sse_response = self._http.send(
                self._http.build_request("GET", f"{self.server_url}/sse"),
                stream=True,
            )
            for line in self._sse_response.iter_lines():
                if "sessionId=" in line:
                    self.session_id = line.split("sessionId=")[1].split("&")[0].strip()
                    logger.info(f"MCP session established: {self.session_id}")
                    break
        except Exception as e:
            logger.error(f"SSE session setup failed: {e}")
            raise RuntimeError(f"Cannot connect to MCP server at {self.server_url}: {e}")

    def call_tool(self, tool_name: str, arguments: dict[str, Any]) -> str:
        """Call an MCP tool and return the result as a string."""
        self._ensure_session()

        try:
            response = self._http.post(
                f"{self.server_url}/messages",
                params={"sessionId": self.session_id},
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

            if response.status_code == 404:
                # Session expired, re-establish and retry once
                logger.warning("Session not found, re-establishing...")
                self.session_id = None
                if self._sse_response:
                    self._sse_response.close()
                    self._sse_response = None
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
