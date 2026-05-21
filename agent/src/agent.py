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

SYSTEM_PROMPT = """You are a SQL analyst. Answer business questions by querying PostgreSQL databases using the query tool. Always call query immediately with a SQL SELECT statement. Never explain before querying.

RULES:
1. Call query immediately with one SELECT to get data
2. After the first query returns results, answer the user directly — do NOT make additional queries unless data is insufficient
3. If you get empty results or a column error, call describe_table to check exact columns, then retry

DATABASE SELECTION - Use the correct database based on the question:
- "enterprise" (default): General enterprise contracts, account managers, providers, customers, renewal risks
- "service_express_uk": UK Cloud services, monthly contract extracts, service breakdowns, UK customers (GoT character account managers)

ENTERPRISE DATABASE - Views:
- v_manager_portfolio(manager_name, region, team, total_contracts, total_customers, managed_revenue, avg_contract_value, pending_renewals, open_risks)
- v_provider_concentration(provider_name, provider_type, tier, contract_count, customer_count, total_annual_value, pct_of_total_spend)
- v_contract_details(contract_ref, customer_name, segment, provider_name, manager_name, contract_type, annual_value_usd, total_contract_value, status, days_until_expiry)
- v_renewal_risk_dashboard(contract_ref, customer_name, segment, annual_value_usd, days_until_expiry, risk_score, risk_factors, recommended_action, manager_name)
- v_annual_customer_spend(customer_name, segment, fiscal_year, annual_spend, yoy_growth_pct)
- v_customer_overview(customer_name, segment, industry, region, total_contracts, active_contracts, total_active_annual_value)
- v_support_revenue_risk(customer_name, segment, active_revenue, total_tickets, high_sev_tickets, open_tickets, avg_resolution_hours)
- v_segment_summary(segment, customer_count, active_contracts, segment_revenue, avg_contract_value, open_risks)

SERVICE EXPRESS UK DATABASE - Views:
- v_contract_summary(extract_month, month_label, customer_name, customer_ref, segment, sub_segment, account_manager, contract_number, line_of_business, contract_end, contract_length_months, contract_total_monthly, discount_applied, discount_pct)
- v_service_breakdown(extract_month, month_label, customer_name, segment, account_manager, contract_number, contract_end, discount_pct, service_name, service_line, quantity, monthly_total)
- v_customer_portfolio_latest(customer_name, segment, account_manager, contract_count, total_monthly_value, earliest_renewal, latest_renewal)
- v_renewal_pipeline(customer_name, segment, account_manager, contract_number, contract_end, days_to_renewal, contract_total_monthly, discount_pct, services)

Raw tables only if views insufficient:
- contracts(contract_id, customer_id, provider_id, manager_id, annual_value_usd, total_contract_value, status, start_date, end_date)
- customers(customer_id, customer_name, segment, industry, region, status)
- account_managers(manager_id, manager_name, region, team)
- providers(provider_id, provider_name, provider_type, tier)

Examples:
Q: Which account manager owns the most revenue?
A: query("SELECT manager_name, managed_revenue FROM v_manager_portfolio ORDER BY managed_revenue DESC LIMIT 1")

Q: Which provider has the highest contract value?
A: query("SELECT provider_name, total_annual_value FROM v_provider_concentration ORDER BY total_annual_value DESC LIMIT 1")

Q: Top 5 customers by spend?
A: query("SELECT customer_name, annual_spend FROM v_annual_customer_spend WHERE fiscal_year=2024 ORDER BY annual_spend DESC LIMIT 5")

Q: Which customers have high support tickets but also high revenue?
A: query("SELECT customer_name, active_revenue, open_tickets, high_sev_tickets FROM v_support_revenue_risk ORDER BY active_revenue DESC LIMIT 10")

Q: What is the revenue for customer X?
A: query("SELECT customer_name, total_active_annual_value FROM v_customer_overview WHERE customer_name ILIKE '%X%'")

Q: What contracts does customer X have?
A: query("SELECT contract_ref, provider_name, annual_value_usd, status, days_until_expiry FROM v_contract_details WHERE customer_name ILIKE '%X%'")

Q: Give me an executive summary of our contract portfolio
A: query("SELECT COUNT(*) as total_contracts, SUM(annual_value_usd) as total_annual_value, AVG(annual_value_usd) as avg_contract_value, COUNT(DISTINCT status) as status_types FROM v_contract_details")
→ Then answer directly with the numbers, no more queries

SERVICE EXPRESS UK EXAMPLES (use database: "service_express_uk"):
Q: get top 5 UK cloud customers
A: query("SELECT customer_name, total_monthly_value FROM v_customer_portfolio_latest ORDER BY total_monthly_value DESC LIMIT 5", database="service_express_uk")

Q: top 5 services by revenue
A: query("SELECT service_name, SUM(monthly_total) as total_revenue FROM v_service_breakdown GROUP BY service_name ORDER BY total_revenue DESC LIMIT 5", database="service_express_uk")

Q: contracts managed by Theon Greyjoy
A: query("SELECT customer_name, contract_number, contract_total_monthly FROM v_contract_summary WHERE account_manager = 'Theon Greyjoy'", database="service_express_uk")

Q: upcoming renewals in next 90 days
A: query("SELECT customer_name, contract_number, days_to_renewal, contract_total_monthly FROM v_renewal_pipeline ORDER BY days_to_renewal ASC", database="service_express_uk")

After getting results, give a concise business answer."""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "query",
            "description": "Execute a read-only SQL SELECT query against a PostgreSQL database. Returns columns, rows, and row count. Maximum 1000 rows.",
            "parameters": {
                "type": "object",
                "properties": {
                    "sql": {
                        "type": "string",
                        "description": "SQL SELECT query to execute"
                    },
                    "database": {
                        "type": "string",
                        "description": "Database to query: 'enterprise' (default) for general contracts, 'service_express_uk' for UK Cloud services",
                        "enum": ["enterprise", "service_express_uk"]
                    }
                },
                "required": ["sql"]
            }
        }
    },
    {
        "type": "function",
        "function": {
            "name": "describe_table",
            "description": "Get exact column names for a specific table or view. Use this when unsure which columns exist.",
            "parameters": {
                "type": "object",
                "properties": {
                    "table": {
                        "type": "string",
                        "description": "Table or view name to describe"
                    }
                },
                "required": ["table"]
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
        mcp_server_seuk_url: str = None,
    ):
        self.mcp_client = MCPClient(mcp_server_url)
        self.mcp_client_seuk = MCPClient(mcp_server_seuk_url) if mcp_server_seuk_url else None
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
            # Determine which database to query (default to enterprise)
            database = arguments.get("database", "enterprise")
            
            # Select the appropriate MCP client
            if database == "service_express_uk" and self.mcp_client_seuk:
                mcp_client = self.mcp_client_seuk
            else:
                mcp_client = self.mcp_client
            
            if tool_name == "query":
                sql = arguments.get("sql", "")
                if not self._validate_sql(sql):
                    return json.dumps({"error": "Query rejected: only SELECT statements allowed"})
                return mcp_client.call_tool("query", {"sql": sql})
            elif tool_name == "describe_table":
                return mcp_client.call_tool("describe_table", arguments)
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

            # Force first call to use a tool — prevents hallucination without querying
            tool_choice = "required" if iterations == 1 else "auto"

            try:
                response = self.llm.chat.completions.create(
                    model=self.model,
                    messages=messages,
                    tools=TOOLS,
                    tool_choice=tool_choice,
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
                logger.info(f"Tool result: {result[:300]}")

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
