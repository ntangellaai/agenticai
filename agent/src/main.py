"""
Service Express UK AI Demo - Agent Web Server
Flask-based UI and API for UK Cloud business analytics via MCP.
"""

import os
import logging
from flask import Flask, request, jsonify, render_template_string
from agent import SEUKAgent

# Configuration
MCP_SERVER_URL = os.environ.get("MCP_SERVER_URL", "http://mcp-server-seuk-svc:3001")
LLM_ENDPOINT = os.environ.get("LLM_ENDPOINT", "http://llm-svc.llm.svc.cluster.local:8080/v1")
LLM_API_KEY = os.environ.get("LLM_API_KEY", "")
LLM_MODEL = os.environ.get("LLM_MODEL", "ibm/granite-3-8b-instruct")
LLM_TIMEOUT = int(os.environ.get("LLM_TIMEOUT", "120"))
AGENT_PORT = int(os.environ.get("AGENT_PORT", "8080"))
MAX_QUERY_LENGTH = int(os.environ.get("MAX_QUERY_LENGTH", "2000"))

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("agent")

# Flask app
app = Flask(__name__)

# Agent instance
agent = SEUKAgent(
    mcp_server_url=MCP_SERVER_URL,
    llm_endpoint=LLM_ENDPOINT,
    llm_api_key=LLM_API_KEY,
    llm_model=LLM_MODEL,
    llm_timeout=LLM_TIMEOUT,
)

# HTML template for the UI
UI_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Enterprise AI Assistant</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'IBM Plex Sans', -apple-system, sans-serif; background: #f4f4f4; color: #161616; }
        .header { background: #161616; color: white; padding: 1rem 2rem; }
        .header h1 { font-size: 1.25rem; font-weight: 400; }
        .header .subtitle { font-size: 0.875rem; color: #c6c6c6; margin-top: 0.25rem; }
        .container { max-width: 900px; margin: 2rem auto; padding: 0 1rem; }
        .chat-area { background: white; border: 1px solid #e0e0e0; border-radius: 4px; min-height: 400px; max-height: 600px; overflow-y: auto; padding: 1.5rem; margin-bottom: 1rem; }
        .message { margin-bottom: 1.5rem; }
        .message.user { }
        .message.assistant { background: #f4f4f4; padding: 1rem; border-radius: 4px; border-left: 3px solid #0f62fe; }
        .message .role { font-size: 0.75rem; font-weight: 600; text-transform: uppercase; color: #525252; margin-bottom: 0.5rem; }
        .message .content { font-size: 0.9rem; line-height: 1.6; white-space: pre-wrap; }
        .message .tool-calls { font-size: 0.8rem; color: #525252; margin-top: 0.5rem; font-style: italic; }
        .input-area { display: flex; gap: 0.5rem; }
        .input-area input { flex: 1; padding: 0.75rem 1rem; border: 2px solid #e0e0e0; border-radius: 4px; font-size: 0.9rem; }
        .input-area input:focus { outline: none; border-color: #0f62fe; }
        .input-area button { padding: 0.75rem 1.5rem; background: #0f62fe; color: white; border: none; border-radius: 4px; font-size: 0.9rem; cursor: pointer; }
        .input-area button:hover { background: #0353e9; }
        .input-area button:disabled { background: #c6c6c6; cursor: not-allowed; }
        .status { font-size: 0.8rem; color: #525252; margin-top: 0.5rem; }
        .examples { margin-top: 1.5rem; }
        .examples h3 { font-size: 0.875rem; color: #525252; margin-bottom: 0.5rem; }
        .examples button { display: block; text-align: left; background: none; border: 1px solid #e0e0e0; padding: 0.5rem 1rem; margin-bottom: 0.25rem; border-radius: 4px; cursor: pointer; font-size: 0.8rem; width: 100%; }
        .examples button:hover { background: #e8e8e8; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Service Express UK AI Assistant</h1>
        <div class="subtitle">UK Cloud Business Analytics | Powered by PostgreSQL MCP on IBM Power (ppc64le) | OpenShift</div>
    </div>
    <div class="container">
        <div class="chat-area" id="chat"></div>
        <div class="input-area">
            <input type="text" id="question" placeholder="Ask a business question..." maxlength="2000" />
            <button id="send" onclick="ask()">Ask</button>
        </div>
        <div class="status" id="status"></div>
        <div class="examples">
            <h3>Example Questions:</h3>
            <button onclick="setQ('Top 5 UK cloud customers by monthly value')">Top 5 UK cloud customers by monthly value</button>
            <button onclick="setQ('Which services generate the most revenue?')">Which services generate the most revenue?</button>
            <button onclick="setQ('Contracts managed by Theon Greyjoy')">Contracts managed by Theon Greyjoy</button>
            <button onclick="setQ('Upcoming contract renewals in next 90 days')">Upcoming contract renewals in next 90 days</button>
            <button onclick="setQ('Total monthly revenue by customer segment')">Total monthly revenue by customer segment</button>
            <button onclick="setQ('Give me an executive summary of our UK Cloud portfolio')">Give me an executive summary of our UK Cloud portfolio</button>
        </div>
    </div>
    <script>
        function setQ(q) { document.getElementById('question').value = q; }
        async function ask() {
            const input = document.getElementById('question');
            const btn = document.getElementById('send');
            const chat = document.getElementById('chat');
            const status = document.getElementById('status');
            const q = input.value.trim();
            if (!q) return;

            // Add user message
            chat.innerHTML += '<div class="message user"><div class="role">You</div><div class="content">' + escapeHtml(q) + '</div></div>';
            input.value = '';
            btn.disabled = true;
            status.textContent = 'Thinking...';

            try {
                const ctrl = new AbortController();
                setTimeout(() => ctrl.abort(), 600000); // 600s timeout to match route
                const res = await fetch('/api/ask', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ question: q }),
                    signal: ctrl.signal
                });
                let data;
                const text = await res.text();
                try { data = JSON.parse(text); } catch(_) {
                    data = { answer: res.status === 504 || res.status === 502
                        ? 'The request timed out. The language model is busy — please wait 30 seconds and try again.'
                        : 'Unexpected server error (status ' + res.status + '). Please try again.' };
                }
                let html = '<div class="message assistant"><div class="role">Assistant</div>';
                html += '<div class="content">' + escapeHtml(data.answer || data.error || 'No response') + '</div>';
                if (data.tool_calls && data.tool_calls.length > 0) {
                    html += '<div class="tool-calls">Tools used: ' + data.tool_calls.map(t => t.tool).join(', ') + '</div>';
                }
                html += '</div>';
                chat.innerHTML += html;
            } catch (e) {
                chat.innerHTML += '<div class="message assistant"><div class="role">Error</div><div class="content">Network error: ' + e.message + '</div></div>';
            }

            btn.disabled = false;
            status.textContent = '';
            chat.scrollTop = chat.scrollHeight;
        }
        function escapeHtml(t) { const d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
        document.getElementById('question').addEventListener('keydown', e => { if (e.key === 'Enter') ask(); });
    </script>
</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(UI_TEMPLATE)


@app.route("/health")
def health():
    return jsonify({"status": "healthy", "agent": "ready"})


@app.route("/api/ask", methods=["POST"])
def ask():
    data = request.get_json()
    if not data or "question" not in data:
        return jsonify({"error": "Missing 'question' field"}), 400

    question = data["question"].strip()

    if not question:
        return jsonify({"error": "Empty question"}), 400

    if len(question) > MAX_QUERY_LENGTH:
        return jsonify({"error": f"Question too long (max {MAX_QUERY_LENGTH} chars)"}), 400

    logger.info(f"Question received: {question[:100]}...")

    try:
        result = agent.answer(question)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Agent error: {e}")
        return jsonify({"error": "Internal agent error. Please try again."}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=AGENT_PORT, debug=False)
