"""
MCP Client - Connects to the PostgreSQL MCP Server via HTTP/SSE.
Lightweight implementation using httpx for SSE transport.
"""

import json
import logging
import queue
import threading
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
        self._sse_thread: threading.Thread | None = None
        self._session_ready = threading.Event()
        # Maps request id -> queue for async SSE responses
        self._pending: dict[str, queue.Queue] = {}
        self._pending_lock = threading.Lock()

    def _ensure_session(self) -> None:
        """Establish SSE session and start background reader thread."""
        if self.session_id:
            return

        self._session_ready.clear()

        def _sse_loop():
            """Keep SSE connection alive; route response events to waiting callers."""
            try:
                with httpx.stream("GET", f"{self.server_url}/sse", timeout=None) as response:
                    event_type = None
                    for line in response.iter_lines():
                        if line.startswith("event:"):
                            event_type = line[6:].strip()
                        elif line.startswith("data:"):
                            data = line[5:].strip()
                            if "sessionId=" in data and not self.session_id:
                                self.session_id = data.split("sessionId=")[1].split("&")[0].strip()
                                logger.info(f"MCP session established: {self.session_id}")
                                self._session_ready.set()
                            elif data and data != "":
                                # Try to parse as JSON-RPC response and route to waiting caller
                                try:
                                    msg = json.loads(data)
                                    req_id = str(msg.get("id", ""))
                                    with self._pending_lock:
                                        q = self._pending.get(req_id)
                                    if q:
                                        q.put(msg)
                                except json.JSONDecodeError:
                                    pass
            except Exception as e:
                logger.warning(f"SSE connection closed: {e}")
            finally:
                self._session_ready.set()  # unblock on error

        self._sse_thread = threading.Thread(target=_sse_loop, daemon=True)
        self._sse_thread.start()

        if not self._session_ready.wait(timeout=10.0):
            raise RuntimeError(f"Timed out waiting for MCP session from {self.server_url}")

        if not self.session_id:
            raise RuntimeError(f"Failed to obtain MCP session ID from {self.server_url}")

    def call_tool(self, tool_name: str, arguments: dict[str, Any], _retry: bool = True) -> str:
        """Call an MCP tool and return the result as a string."""
        self._ensure_session()

        req_id = str(uuid.uuid4())
        response_queue: queue.Queue = queue.Queue()

        with self._pending_lock:
            self._pending[req_id] = response_queue

        try:
            response = self._http.post(
                f"{self.server_url}/messages",
                params={"sessionId": self.session_id},
                json={
                    "jsonrpc": "2.0",
                    "id": req_id,
                    "method": "tools/call",
                    "params": {
                        "name": tool_name,
                        "arguments": arguments,
                    },
                },
                headers={"Content-Type": "application/json"},
            )

            if response.status_code == 404 and _retry:
                # Session expired — reset and retry once only
                logger.warning("Session not found, re-establishing...")
                self.session_id = None
                self._sse_thread = None
                self._ensure_session()
                return self.call_tool(tool_name, arguments, _retry=False)

            if response.status_code not in (200, 202):
                return json.dumps({
                    "error": f"MCP server returned {response.status_code}: {response.text[:200]}"
                })

            # 202 Accepted = async SSE transport; wait for response on the SSE stream
            if response.status_code == 202:
                try:
                    result = response_queue.get(timeout=self.timeout)
                except queue.Empty:
                    return json.dumps({"error": "Tool call timed out waiting for SSE response"})
            else:
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
        finally:
            with self._pending_lock:
                self._pending.pop(req_id, None)

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
