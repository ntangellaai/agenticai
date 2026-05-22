"""
Service Express UK Agent - Orchestrates LLM + MCP tool calls for UK Cloud business analytics.
"""

import json
import logging
import re
from typing import Any
from openai import OpenAI, APIStatusError  # Used for OpenAI-compatible API (local LLM via vLLM/TGI)
from mcp_client import MCPClient

logger = logging.getLogger("agent.core")

SYSTEM_PROMPT = """You are a SQL analyst for Service Express UK. Answer business questions by querying the UK Cloud PostgreSQL database using the query tool. Always call query immediately with a SQL SELECT statement. Never explain before querying.

RULES:
1. Call query immediately with one SELECT to get data
2. After the first query returns results, answer the user directly — do NOT make additional queries unless data is insufficient
3. If you get empty results or a column error, call describe_table to check exact columns, then retry

NOTE: This is UK Cloud business data - format all monetary values in GBP (£), not USD ($).

AVAILABLE VIEWS:
- v_contract_summary(extract_month, month_label, customer_name, customer_ref, segment, sub_segment, account_manager, contract_number, line_of_business, contract_end, contract_length_months, contract_length_label, invoice_frequency_months, contract_total_monthly, discount_applied, discount_pct)
- v_service_breakdown(extract_month, month_label, customer_name, segment, account_manager, contract_number, contract_end, discount_pct, service_name, service_line, quantity, monthly_total)
- v_customer_portfolio_latest(customer_name, segment, account_manager, contract_count, total_monthly_value, earliest_renewal, latest_renewal)
- v_renewal_pipeline(customer_name, segment, account_manager, contract_number, contract_end, days_to_renewal, contract_total_monthly, discount_pct, services)
- v_revenue_by_segment(segment, customer_count, contract_count, total_monthly_revenue, avg_monthly_revenue, min_monthly_revenue, max_monthly_revenue)
- v_account_manager_performance(account_manager, customers_managed, contracts_managed, total_revenue, avg_contract_value, discounted_contracts, avg_discount_pct)
- v_service_revenue_summary(service_name, customer_count, contract_count, total_monthly_revenue, total_quantity, avg_monthly_per_contract)
- v_renewal_urgency(urgency_bucket, contract_count, customer_count, total_monthly_value, avg_days_to_renewal)
- v_executive_summary(total_customers, total_contracts, total_monthly_revenue, avg_customer_value, renewals_90d, total_account_managers)
- v_discount_analysis(discount_applied, contract_count, customer_count, total_monthly_value, avg_discount_pct, min_discount_pct, max_discount_pct)
- v_top_customers(customer_name, segment, account_manager, contract_count, total_monthly_value, earliest_renewal, latest_renewal, revenue_rank)
- v_customer_service_mix(customer_name, segment, service_count, services_used, total_service_revenue)
- v_service_monthly_trends(extract_month, month_label, service_name, customer_count, contract_count, monthly_revenue, total_quantity)
- v_service_performance_6m(service_name, total_revenue_6m, avg_monthly_revenue, peak_customers, min_customers, total_quantity_sold, revenue_rank)
- v_service_decline_12m(service_name, revenue_first_6m, revenue_last_6m, revenue_decline, revenue_decline_pct, customers_first_6m, customers_last_6m, customer_decline, decline_rank_revenue, decline_rank_customers)
- v_low_service_customers(customer_name, segment, account_manager, service_count, services_used, total_service_revenue, service_category)
- v_service_count_distribution(service_category, customer_count, total_revenue, avg_revenue)

VIEW USAGE GUIDE:
- v_customer_portfolio_latest: Use for customer/portfolio analysis (has total_monthly_value per customer, NO contract_total_monthly)
- v_contract_summary: Use for contract-level data (has contract_total_monthly per contract)
- v_renewal_pipeline: Use for renewal tracking (has days_to_renewal)
- v_service_breakdown: Use for service/revenue analysis (has monthly_total per service line)
- v_revenue_by_segment: USE THIS for "revenue by segment" questions - columns already aggregated
- v_account_manager_performance: USE THIS for "best account manager" or "AM performance" questions
- v_service_revenue_summary: USE THIS for "top services" or "service revenue" questions
- v_renewal_urgency: USE THIS for "renewals" or "upcoming renewals" questions - already categorized
- v_executive_summary: USE THIS for "summary" or "overview" questions - single row with totals
- v_discount_analysis: USE THIS for "discount" questions - already grouped by discount_applied
- v_top_customers: USE THIS for "top customers" questions - already ranked with revenue_rank
- v_customer_service_mix: USE THIS for "what services does X use" questions
- v_service_performance_6m: USE THIS for "most sold service" or "service performance" questions - already filtered to last 6 months
- v_service_decline_12m: USE THIS for "declined most" questions - has both revenue and customer decline metrics pre-calculated
- v_low_service_customers: USE THIS for "customers with 3 or fewer services" questions
- v_service_count_distribution: USE THIS for "how many customers by service count" questions

Examples:
Q: get top 5 UK cloud customers
A: query("SELECT customer_name, total_monthly_value FROM v_top_customers WHERE revenue_rank <= 5 ORDER BY revenue_rank", database="service_express_uk")

Q: total revenue by customer segment
A: query("SELECT segment, total_monthly_revenue FROM v_revenue_by_segment ORDER BY total_monthly_revenue DESC", database="service_express_uk")

Q: top 5 services by revenue
A: query("SELECT service_name, total_monthly_revenue FROM v_service_revenue_summary ORDER BY total_monthly_revenue DESC LIMIT 5", database="service_express_uk")

Q: contracts managed by Theon Greyjoy
A: query("SELECT customer_name, contract_number, contract_total_monthly FROM v_contract_summary WHERE account_manager = 'Theon Greyjoy'", database="service_express_uk")

Q: upcoming renewals in next 90 days
A: query("SELECT urgency_bucket, contract_count, total_monthly_value FROM v_renewal_urgency WHERE urgency_bucket != 'Future (90+ days)' ORDER BY avg_days_to_renewal", database="service_express_uk")

Q: which account manager brings in the most revenue
A: query("SELECT account_manager, total_revenue FROM v_account_manager_performance ORDER BY total_revenue DESC LIMIT 1", database="service_express_uk")

Q: executive summary of our UK Cloud portfolio
A: query("SELECT * FROM v_executive_summary", database="service_express_uk")

Q: what service have we sold the most over the last 6 months
A: query("SELECT service_name, total_revenue_6m, total_quantity_sold FROM v_service_performance_6m WHERE revenue_rank = 1", database="service_express_uk")

Q: which service has declined the most in revenue last 12 months
A: query("SELECT service_name, revenue_decline, revenue_decline_pct FROM v_service_decline_12m WHERE decline_rank_revenue = 1", database="service_express_uk")

Q: how many customers take 3 or less services
A: query("SELECT COUNT(*) as customer_count, SUM(total_service_revenue) as total_revenue FROM v_low_service_customers", database="service_express_uk")

Q: show me customers with low service adoption
A: query("SELECT customer_name, service_count, services_used, total_service_revenue FROM v_low_service_customers ORDER BY total_service_revenue DESC LIMIT 10", database="service_express_uk")

After getting results, give a concise business answer. Format all monetary values in GBP (£)."""

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
                        "description": "Database to query (always 'service_express_uk' for UK Cloud data)",
                        "enum": ["service_express_uk"]
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


class SEUKAgent:
    """Orchestrates LLM reasoning with MCP tool execution for Service Express UK."""

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
            timeout=llm_timeout,
            max_retries=0,
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

    def answer_stream(self, question: str):
        """Process a user question through the agent loop with streaming support.
        Yields SSE events: status updates, tool calls, and answer chunks."""
        import time

        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": question},
        ]

        tool_calls_log = []
        iterations = 0

        # Yield initial status
        yield f"event: status\ndata: {json.dumps({'message': 'Thinking...'})}\n\n"

        while iterations < self.max_tool_calls:
            if len(messages) > 8:
                messages = messages[:2] + messages[-6:]
            iterations += 1

            tool_choice = "required" if iterations == 1 else "auto"

            try:
                yield f"event: status\ndata: {json.dumps({'message': f'Querying database (step {iterations})...'})}\n\n"
                time.sleep(0.1)  # Allow client to receive status

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
                    yield f"event: error\ndata: {json.dumps({'message': 'LLM server busy, please retry'})}\n\n"
                    return
                yield f"event: error\ndata: {json.dumps({'message': str(e)})}\n\n"
                return
            except Exception as e:
                yield f"event: error\ndata: {json.dumps({'message': str(e)})}\n\n"
                return

            choice = response.choices[0]
            message = choice.message

            # If no tool calls, we have our final answer
            if not message.tool_calls:
                # Stream the answer in chunks
                answer = message.content or "I wasn't able to generate a response."
                # Split into ~50 char chunks for smoother streaming
                chunk_size = 50
                for i in range(0, len(answer), chunk_size):
                    chunk = answer[i:i+chunk_size]
                    yield f"event: answer\ndata: {json.dumps({'chunk': chunk, 'done': i + chunk_size >= len(answer)})}\n\n"
                    time.sleep(0.05)  # Small delay for natural feeling
                return

            # Process tool calls
            messages.append(message.model_dump())

            for tool_call in message.tool_calls:
                fn_name = tool_call.function.name
                try:
                    fn_args = json.loads(tool_call.function.arguments)
                except json.JSONDecodeError:
                    fn_args = {}

                logger.info(f"Tool call: {fn_name}({json.dumps(fn_args)[:200]})")
                yield f"event: tool\ndata: {json.dumps({'tool': fn_name, 'arguments': fn_args})}\n\n"
                time.sleep(0.1)

                result = self._call_tool(fn_name, fn_args)
                logger.info(f"Tool result: {result[:300]}")

                tool_calls_log.append({
                    "tool": fn_name,
                    "arguments": fn_args,
                    "result_preview": result[:200] if len(result) > 200 else result,
                })

                # Yield tool result summary
                result_data = json.loads(result) if result.startswith('{') else {"result": result[:100]}
                yield f"event: tool_result\ndata: {json.dumps({'tool': fn_name, 'result': result_data})}\n\n"

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result,
                })

        # Hit max iterations
        yield f"event: answer\ndata: {json.dumps({'chunk': 'I reached the maximum number of queries. Here is what I found:', 'done': False})}\n\n"
        yield f"event: answer\ndata: {json.dumps({'chunk': '', 'done': True})}\n\n"
