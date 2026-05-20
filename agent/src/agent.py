"""
Enterprise Agent - Orchestrates LLM + MCP tool calls for business question answering.
"""

import json
import logging
import re
from typing import Any
from openai import OpenAI, APIStatusError  # Used for OpenAI-compatible API (local LLM via vLLM/TGI)
from mcp_client import MCPClient

logger = logging.getLogger("agent.core")

SYSTEM_PROMPT = """You are an enterprise business analyst AI assistant. You have access to a PostgreSQL database containing contract, customer, provider, and operational data.

Your role:
- Answer business questions about contracts, customers, spend, risk, and operations
- Use SQL queries via the available tools to retrieve data
- Explain findings in clear business language
- Cite specific contract IDs, customer names, or data points in your answers
- Identify trends, risks, and opportunities

Rules:
- ONLY use SELECT queries. Never attempt INSERT, UPDATE, DELETE, or any DDL.
- The schema is provided above — do NOT call list_tables or describe_table, go directly to query.
- Keep queries efficient - use appropriate WHERE clauses and LIMIT.
- Prefer views over raw table joins when available.
- Always explain your reasoning and cite the data that supports your conclusions.
- If the data is insufficient to answer, say so clearly.
- Maximum 5 tool calls per question.

Schema (exact column names):
- contracts(contract_id, customer_id, provider_id, manager_id, contract_type, start_date, end_date, annual_value_usd, total_contract_value, status)
- customers(customer_id, customer_name, segment, industry, region, annual_revenue_usd, status)
- account_managers(manager_id, manager_name, region, team)
- providers(provider_id, provider_name, provider_type, tier)
- spend_history(customer_id, contract_id, fiscal_year, fiscal_quarter, amount_usd, category)
- contract_events(contract_id, event_type, event_date, old_value_usd, new_value_usd)
- support_tickets(customer_id, contract_id, severity, status, opened_date)
- renewal_risks(contract_id, risk_score, owner_manager_id)

Joins: contracts.customer_id=customers.customer_id, contracts.manager_id=account_managers.manager_id, contracts.provider_id=providers.provider_id

Prefer these views (already have joins built in):
- v_manager_portfolio: manager_name, total_contract_value, active_contracts, avg_contract_value
- v_contract_details: contract_ref, customer_name, manager_name, provider_name, annual_value_usd, status
- v_renewal_risk_dashboard: customer_name, contract_ref, risk_score, recommended_action
- v_annual_customer_spend: customer_name, fiscal_year, total_spend, yoy_growth_pct
- v_provider_concentration: provider_name, total_value, contract_count
- v_segment_summary: segment, total_value, customer_count
- v_customer_overview: customer_name, segment, active_contracts, total_value
- v_support_revenue_risk: customer_name, open_tickets, critical_tickets, total_contract_value

Example — account manager with most revenue:
SELECT manager_name, total_contract_value FROM v_manager_portfolio ORDER BY total_contract_value DESC LIMIT 1;"""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query",
            "description": "Execute a read-only SQL SELECT query against the enterprise database. Returns columns, rows, and row count. Maximum 1000 rows.",
            "parameters": {
                "type": "object",
                "properties": {
                    "sql": {
                        "type": "string",
                        "description": "SQL SELECT query to execute"
                    }
                },
                "required": ["sql"]
            }
        }
    }
]


class EnterpriseAgent:
    """Orchestrates LLM reasoning with MCP tool execution."""

    def __init__(
        self,
        mcp_server_url: str,
        llm_endpoint: str,
        llm_api_key: str,
        llm_model: str,
        max_tool_calls: int = 5,
        llm_timeout: int = 120,
    ):
        self.mcp_client = MCPClient(mcp_server_url)
        self.llm = OpenAI(
            base_url=llm_endpoint,
            api_key=llm_api_key,
            timeout=llm_timeout,  # llama.cpp on Power10 may need longer inference time
            max_retries=0,  # Don't retry on 500 — llama.cpp returns 500 when slots are full
        )
        self.model = llm_model
        self.max_tool_calls = max_tool_calls

    def _validate_sql(self, sql: str) -> bool:
        """Agent-side SQL validation (defence in depth)."""
        normalized = sql.strip().upper()
        if not (normalized.startswith("SELECT") or normalized.startswith("WITH")):
            return False
        blocked = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "CREATE",
                   "TRUNCATE", "GRANT", "REVOKE"]
        for kw in blocked:
            if re.search(rf"\b{kw}\b", normalized):
                return False
        return True

    def _call_tool(self, tool_name: str, arguments: dict[str, Any]) -> str:
        """Execute a tool call via MCP client."""
        try:
            if tool_name == "query":
                sql = arguments.get("sql", "")
                if not self._validate_sql(sql):
                    return json.dumps({"error": "Query rejected: only SELECT statements allowed"})
                return self.mcp_client.call_tool("query", {"sql": sql})
            elif tool_name == "list_tables":
                return self.mcp_client.call_tool("list_tables", {})
            elif tool_name == "describe_table":
                return self.mcp_client.call_tool("describe_table", arguments)
            else:
                return json.dumps({"error": f"Unknown tool: {tool_name}"})
        except Exception as e:
            logger.error(f"Tool call error ({tool_name}): {e}")
            return json.dumps({"error": f"Tool execution failed: {str(e)}"})

    def answer(self, question: str) -> dict[str, Any]:
        """Process a user question through the agent loop."""
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": question},
        ]

        tool_calls_log = []
        iterations = 0

        while iterations < self.max_tool_calls:
            # Trim history: keep system + user message + last 6 messages to fit in 2048 ctx
            if len(messages) > 8:
                messages = messages[:2] + messages[-6:]
            iterations += 1

            try:
                response = self.llm.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    tools=TOOLS,
                    tool_choice="auto",
                    temperature=0.1,
                    max_tokens=768,
                )
            except APIStatusError as e:
                if e.status_code == 500:
                    logger.error(f"LLM busy (500): {e}")
                    return {
                        "answer": "The language model is currently busy processing another request. Please wait a moment and try again.",
                        "tool_calls": tool_calls_log,
                        "error": "LLM server busy",
                    }
                logger.error(f"LLM call failed: {e}")
                return {
                    "answer": "I'm unable to process your question right now. The language model service may be unavailable.",
                    "tool_calls": tool_calls_log,
                    "error": str(e),
                }
            except Exception as e:
                logger.error(f"LLM call failed: {e}")
                return {
                    "answer": "I'm unable to process your question right now. The language model service may be unavailable.",
                    "tool_calls": tool_calls_log,
                    "error": str(e),
                }

            choice = response.choices[0]
            message = choice.message

            # If no tool calls, we have our final answer
            if not message.tool_calls:
                return {
                    "answer": message.content or "I wasn't able to generate a response.",
                    "tool_calls": tool_calls_log,
                }

            # Process tool calls
            messages.append(message.model_dump())

            for tool_call in message.tool_calls:
                fn_name = tool_call.function.name
                try:
                    fn_args = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError:
                    fn_args = {}

                logger.info(f"Tool call: {fn_name}({json.dumps(fn_args)[:200]})")

                result = self._call_tool(fn_name, fn_args)

                tool_calls_log.append({
                    "tool": fn_name,
                    "arguments": fn_args,
                    "result_preview": result[:200] if len(result) > 200 else result,
                })

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result,
                })

        # Hit max iterations
        return {
            "answer": "I reached the maximum number of queries while processing your question. Here's what I found so far based on the data retrieved.",
            "tool_calls": tool_calls_log,
            "warning": "Max tool calls reached",
        }
