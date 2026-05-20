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
        self._http = httpx.Client(timeout=timeout)

    def _call_over_sse(self, req_id: str, payload: dict) -> dict:
        """
        Open a fresh SSE connection, post the JSON-RPC request, read the
        response from the SSE stream, then close.  One SSE connection per call.
        """
        with httpx.stream("GET", f"{self.server_url}/sse",
                          timeout=self.timeout) as sse:
            session_id = None
            buffer = ""
            for line in sse.iter_lines():
                logger.debug(f"SSE line: {line!r}")

                # Strip SSE field prefix for uniform handling
                raw = line
                if line.startswith("data:"):
                    raw = line[5:].strip()
                elif line.startswith("event:") or line == "":
                    continue

                # First meaningful line: endpoint event with sessionId
                if session_id is None:
                    if "sessionId=" in raw:
                        session_id = raw.split("sessionId=")[1].split("&")[0].split()[0].strip()
                        logger.info(f"MCP session: {session_id}")

                        post_resp = self._http.post(
                            f"{self.server_url}/messages",
                            params={"sessionId": session_id},
                            json=payload,
                            headers={"Content-Type": "application/json"},
                        )
                        if post_resp.status_code not in (200, 202):
                            raise RuntimeError(
                                f"MCP POST returned {post_resp.status_code}: {post_resp.text[:200]}"
                            )
                    continue

                # Subsequent lines: JSON-RPC response
                if not raw:
                    continue

                buffer += raw
                try:
                    msg = json.loads(buffer)
                    buffer = ""
                    if str(msg.get("id")) == req_id:
                        return msg
                except json.JSONDecodeError:
                    # Incomplete JSON — accumulate more lines
                    pass

        raise RuntimeError("SSE stream closed before receiving response")

    def call_tool(self, tool_name: str, arguments: dict[str, Any]) -> str:
        """Call an MCP tool and return the result as a string."""
        req_id = str(uuid.uuid4())
        payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": "tools/call",
            "params": {"name": tool_name, "arguments": arguments},
        }
        try:
            result = self._call_over_sse(req_id, payload)

            if "error" in result:
                return json.dumps({"error": result["error"].get("message", "Unknown MCP error")})

            content = result.get("result", {}).get("content", [])
            if content:
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

