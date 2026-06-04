"""
Service Express UK Agent - Orchestrates LLM + MCP tool calls for UK Cloud business analytics.
"""

import json
import logging
import re
from typing import Any
import httpx
from openai import OpenAI, APIStatusError  # Used for OpenAI-compatible API (local LLM via vLLM/TGI)
from mcp_client import MCPClient

logger = logging.getLogger("agent.core")

# STABLE SYSTEM PROMPT - Identical for all requests to maximize KV cache reuse
# Keep this compact and constant - llama.cpp will cache these tokens
SYSTEM_PROMPT = """You are a SQL analyst for Service Express UK. Query the database using the query tool. Always call query immediately with SELECT. Never explain before querying.

Rules:
1. Call query immediately with one SELECT
2. Answer directly after first query result - no more queries unless needed
3. Use describe_table if column error, then retry
4. Format money columns in GBP (£). Counts/numbers are NOT money - report as plain numbers
5. Use ILIKE '%term%' for name/service filters (never exact match)

Base views: v_contract_summary,v_service_breakdown,v_customer_portfolio_latest,v_renewal_pipeline
Analytics views: v_revenue_by_segment,v_account_manager_performance,v_service_revenue_summary,v_renewal_urgency,v_executive_summary,v_discount_analysis,v_top_customers,v_customer_service_mix,v_service_monthly_trends,v_service_performance_6m,v_service_decline_12m,v_low_service_customers,v_service_count_distribution
Trend views: v_customer_monthly_headcount,v_customer_monthly_changes,v_customer_win_loss_summary,v_revenue_monthly_trend

View hints: v_customer_portfolio_latest=customer totals(customer_name,total_monthly_value,contract_count,account_manager - NO service_name), v_contract_summary=per contract(contract_number,customer_name,account_manager,line_of_business,contract_total_monthly), v_service_breakdown=service line detail(service_name,customer_name,monthly_total,extract_month YYYY-MM), v_revenue_by_segment=aggregated segments, v_account_manager_performance=AM ranking, v_service_revenue_summary=service ranking(service_name), v_renewal_urgency=renewal categories, v_executive_summary=totals single row, v_discount_analysis=discount groups, v_top_customers=pre-ranked customers, v_customer_service_mix=customer services(service_name,customer_name), v_service_monthly_trends=monthly trends(service_name,extract_month,monthly_revenue), v_service_performance_6m=6mo service sales(service_name), v_service_decline_12m=revenue decline 12mo(service_name), v_low_service_customers=3 or fewer services, v_service_count_distribution=service count stats, v_customer_monthly_headcount=customers+revenue per month(extract_month,customer_count,total_monthly_revenue), v_customer_monthly_changes=per-customer New/Retained/Lost per month(customer_name,status,extract_month), v_customer_win_loss_summary=won/lost/retained counts for 3/6/9/12mo periods(period_months,customers_won,customers_lost,customers_retained,start_month,end_month), v_revenue_monthly_trend=monthly revenue with MoM change(extract_month,total_monthly_revenue,revenue_change,revenue_change_pct)
IMPORTANT: For queries about a specific service use v_service_breakdown or v_customer_service_mix (they have service_name). v_customer_portfolio_latest does NOT have service_name.

After results: concise business answer. GBP format."""

# EXAMPLES - Used in first user message for context (not in system prompt for KV cache stability)
EXAMPLES_CONTEXT = """Examples of correct queries:
- Top customers: query("SELECT customer_name,total_monthly_value FROM v_top_customers WHERE revenue_rank<=5",database="service_express_uk")
- Revenue by segment: query("SELECT segment,total_monthly_revenue FROM v_revenue_by_segment",database="service_express_uk")
- Best AM: query("SELECT account_manager,total_revenue FROM v_account_manager_performance ORDER BY total_revenue DESC LIMIT 1",database="service_express_uk")
- Executive summary: query("SELECT * FROM v_executive_summary",database="service_express_uk")
- Service performance 6m: query("SELECT service_name,total_revenue_6m FROM v_service_performance_6m WHERE revenue_rank=1",database="service_express_uk")
- Service decline: query("SELECT service_name,revenue_decline_pct FROM v_service_decline_12m WHERE decline_rank_revenue=1",database="service_express_uk")
- Low service customers: query("SELECT customer_name,service_count FROM v_low_service_customers",database="service_express_uk")
- Customers for a service: query("SELECT COUNT(DISTINCT customer_name) FROM v_service_breakdown WHERE service_name ILIKE '%Cloud%'",database="service_express_uk")
- Contracts by AM: query("SELECT contract_number,customer_name,line_of_business,contract_total_monthly FROM v_contract_summary WHERE account_manager ILIKE '%Smith%'",database="service_express_uk")
- Customer wins/losses 6 months: query("SELECT period_months,customers_won,customers_lost,customers_retained FROM v_customer_win_loss_summary WHERE period_months=6",database="service_express_uk")
- Customer wins/losses all periods: query("SELECT period_months,start_month,end_month,customers_won,customers_lost,customers_retained FROM v_customer_win_loss_summary ORDER BY period_months",database="service_express_uk")
- Revenue trend: query("SELECT extract_month,customer_count,total_monthly_revenue,revenue_change_pct FROM v_revenue_monthly_trend ORDER BY extract_month",database="service_express_uk")
- New customers this month: query("SELECT customer_name,segment,account_manager FROM v_customer_monthly_changes WHERE status='New' AND extract_month=(SELECT MAX(extract_month) FROM extract_months)",database="service_express_uk")
- Lost customers last 3 months: query("SELECT customer_name,segment,monthly_value FROM v_customer_monthly_changes WHERE status='Lost' AND extract_month >= TO_CHAR(CURRENT_DATE - INTERVAL '3 months','YYYY-MM') ORDER BY monthly_value DESC",database="service_express_uk")
- Compare service customers two months: query("SELECT '2025-06' AS period, COUNT(DISTINCT customer_name) AS customer_count FROM v_service_breakdown WHERE service_name ILIKE '%x86 IaaS%' AND extract_month='2025-06' UNION ALL SELECT '2026-05', COUNT(DISTINCT customer_name) FROM v_service_breakdown WHERE service_name ILIKE '%x86 IaaS%' AND extract_month='2026-05'",database="service_express_uk")

Now answer this question:"""

# DIRECT ANSWERS - Bypass LLM entirely for common queries (instant response)
# Format: pattern keywords -> (SQL query, formatter function)
DIRECT_ANSWERS = {
    # Top customers queries
    r"top\s+\d+|best\s+customers?|largest\s+customers?": {
        "sql": "SELECT customer_name, total_monthly_value FROM v_top_customers ORDER BY revenue_rank LIMIT 5",
        "formatter": lambda rows: "**Top 5 Customers by Monthly Value:**\n\n" + 
            "\n".join([f"{i+1}. **{r['customer_name']}**: £{float(r['total_monthly_value']):,.2f}" 
                       for i, r in enumerate(rows)]) if rows else "No customer data found."
    },
    # Revenue by segment
    r"revenue\s+by\s+segment|segment\s+revenue|monthly\s+revenue\s+by|total.*revenue.*segment": {
        "sql": "SELECT segment, customer_count, total_monthly_revenue FROM v_revenue_by_segment ORDER BY total_monthly_revenue DESC",
        "formatter": lambda rows: "**Revenue by Customer Segment:**\n\n" + 
            "\n".join([f"- **{r['segment']}**: £{float(r['total_monthly_revenue']):,.2f} ({r['customer_count']} customers)" 
                       for r in rows]) if rows else "No segment data found."
    },
    # Executive summary
    r"executive\s+summary|portfolio\s+summary|overview": {
        "sql": "SELECT * FROM v_executive_summary LIMIT 1",
        "formatter": lambda rows: (
            f"**Executive Summary - UK Cloud Portfolio**\n\n"
            f"- **Total Customers:** {rows[0]['total_customers']}\n"
            f"- **Total Contracts:** {rows[0]['total_contracts']}\n" 
            f"- **Monthly Revenue:** £{float(rows[0]['total_monthly_revenue']):,.2f}\n"
            f"- **Average Customer Value:** £{float(rows[0]['avg_customer_value']):,.2f}\n"
            f"- **Renewals (90 days):** {rows[0]['renewals_90d']}\n"
            f"- **Account Managers:** {rows[0]['total_account_managers']}"
        ) if rows else "No summary data available."
    },
    # Best account manager
    r"best\s+account\s+manager|top\s+account\s+manager|am\s+performance": {
        "sql": "SELECT account_manager, customers_managed, total_revenue FROM v_account_manager_performance ORDER BY total_revenue DESC LIMIT 1",
        "formatter": lambda rows: (
            f"**Top Account Manager:** **{rows[0]['account_manager']}**\n\n"
            f"- Customers Managed: {rows[0]['customers_managed']}\n"
            f"- Total Revenue: £{float(rows[0]['total_revenue']):,.2f}"
        ) if rows else "No account manager data found."
    },
    # Top services
    r"top\s+services?|best\s+services?|service\s+revenue|services?\s+(generate|make)|most\s+revenue": {
        "sql": "SELECT service_name, customer_count, total_monthly_revenue FROM v_service_revenue_summary ORDER BY total_monthly_revenue DESC LIMIT 5",
        "formatter": lambda rows: "**Top 5 Services by Revenue:**\n\n" + 
            "\n".join([f"{i+1}. **{r['service_name']}**: £{float(r['total_monthly_revenue']):,.2f} ({r['customer_count']} customers)" 
                       for i, r in enumerate(rows)]) if rows else "No service data found."
    },
    # Most sold service 6m
    r"sold\s+the\s+most|most\s+sold|service\s+performance|6\s*month": {
        "sql": "SELECT service_name, total_revenue_6m, total_quantity_sold FROM v_service_performance_6m WHERE revenue_rank = 1 LIMIT 1",
        "formatter": lambda rows: (
            f"**Most Sold Service (Last 6 Months):** **{rows[0]['service_name']}**\n\n"
            f"- Total Revenue: £{float(rows[0]['total_revenue_6m']):,.2f}\n"
            f"- Quantity Sold: {rows[0]['total_quantity_sold']}"
        ) if rows else "No service performance data found."
    },
    # Service decline - customer count (only when asking about a service declining, not general win/loss)
    r"declin\w*.*(?:number|count|customers?)|(?:number|count|customers?).*declin\w*|fewer.*customers?": {
        "sql": "SELECT service_name, customer_decline, customer_decline_pct FROM v_service_decline_12m WHERE decline_rank_customers = 1 LIMIT 1",
        "formatter": lambda rows: (
            f"**Most Declined Service by Customers (12 Months):** **{rows[0]['service_name']}**\n\n"
            f"- Customer Decline: {rows[0]['customer_decline']} customers\n"
            f"- Decline Percentage: {rows[0]['customer_decline_pct']}%"
        ) if rows else "No decline data found."
    },
    # Service decline - revenue (default)
    r"declin\w*|worst\s+performing": {
        "sql": "SELECT service_name, revenue_decline, revenue_decline_pct FROM v_service_decline_12m WHERE decline_rank_revenue = 1 LIMIT 1",
        "formatter": lambda rows: (
            f"**Most Declined Service by Revenue (12 Months):** **{rows[0]['service_name']}**\n\n"
            f"- Revenue Decline: £{float(rows[0]['revenue_decline']):,.2f}\n"
            f"- Decline Percentage: {rows[0]['revenue_decline_pct']}%"
        ) if rows else "No decline data found."
    },
    # Renewal urgency
    r"renewals?|upcoming|expire": {
        "sql": "SELECT urgency_bucket, contract_count, total_monthly_value, avg_days_to_renewal FROM v_renewal_urgency WHERE urgency_bucket != 'Future (90+ days)' ORDER BY avg_days_to_renewal",
        "formatter": lambda rows: "**Upcoming Renewals:**\n\n" + 
            "\n".join([f"- **{r['urgency_bucket']}**: {r['contract_count']} contracts, £{float(r['total_monthly_value']):,.2f} (avg {r['avg_days_to_renewal']} days)" 
                       for r in rows]) if rows else "No upcoming renewals found."
    },
    # Revenue trend month by month for top service lines
    r"revenue\s+(trend|line|lines?|month|over\s+time)|trend\s+.*revenue\s+line|service\s+line.*trend": {
        "sql": "SELECT service_name, extract_month, monthly_revenue FROM v_service_monthly_trends WHERE service_name IN (SELECT service_name FROM v_service_revenue_summary ORDER BY total_monthly_revenue DESC LIMIT 2) ORDER BY service_name, extract_month",
        "formatter": lambda rows: (
            "**Revenue Trend for Top 2 Service Lines (Month by Month):**\n\n" +
            "\n".join([
                f"- **{r['service_name']}** ({r['extract_month']}): £{float(r['monthly_revenue']):,.2f}"
                for r in rows
            ])
        ) if rows else "No revenue trend data found."
    },
    # Revenue by segment (snapshot)
    r"revenue\s+(by\s+segment|changed|year)|year\s+over\s+year|last\s+year": {
        "sql": "SELECT segment, total_monthly_revenue FROM v_revenue_by_segment ORDER BY total_monthly_revenue DESC",
        "formatter": lambda rows: "**Current Revenue by Segment:**\n\n" + 
            "\n".join([f"- **{r['segment']}**: £{float(r['total_monthly_revenue']):,.2f}" 
                       for r in rows[:5]]) if rows else "No revenue data found."
    },
}


def try_direct_answer(question: str, mcp_client) -> tuple[bool, str]:
    """Try to answer question directly without LLM. Returns (success, answer)."""
    import re
    q_lower = question.lower()
    
    for pattern, config in DIRECT_ANSWERS.items():
        if re.search(pattern, q_lower):
            try:
                result = mcp_client.call_tool("query", {"sql": config["sql"]})
                data = json.loads(result)
                rows = data.get("rows", [])
                return True, config["formatter"](rows)
            except Exception as e:
                logger.warning(f"Direct answer failed for pattern '{pattern}': {e}")
                return False, ""
    
    return False, ""


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
        llm_timeout: int = 600,
    ):
        self.mcp_client = MCPClient(mcp_server_url)
        self.llm = OpenAI(
            base_url=llm_endpoint,
            api_key=llm_api_key,
            timeout=httpx.Timeout(llm_timeout, connect=30.0),
            max_retries=0,
        )
        self.model = llm_model
        self.max_tool_calls = max_tool_calls

    # Patterns that indicate prompt injection attempts
    _INJECTION_PATTERNS = [
        r"ignore\s+(your\s+)?(previous|prior|all)\s+instructions",
        r"(forget|disregard)\s+(you\s+are|your\s+role|instructions)",
        r"\[\s*system\s*\]",
        r"new\s+instructions\s*:",
        r"you\s+are\s+now\s+(in\s+)?admin\s+mode",
        r"as\s+a\s+dba\s+assistant",
        r"disable\s+all\s+filters",
        r"execute\s+this\s+as\s+(the\s+)?postgres\s+superuser",
    ]

    # System/catalog tables the LLM should never query
    _BLOCKED_TABLES = [
        r"pg_shadow", r"pg_authid", r"pg_catalog", r"pg_user",
        r"pg_roles", r"pg_type", r"pg_class", r"pg_namespace",
        r"information_schema",
        r"pg_read_file", r"pg_ls_dir", r"pg_read_binary_file",
        r"current_setting\s*\(",
    ]

    def _check_injection(self, question: str) -> bool:
        """Return True if question looks like a prompt injection attempt."""
        q = question.lower()
        for pattern in self._INJECTION_PATTERNS:
            if re.search(pattern, q):
                return True
        return False

    def _validate_sql(self, sql: str) -> bool:
        """Agent-side SQL validation (defence in depth)."""
        normalized = sql.strip().upper()
        if not (normalized.startswith("SELECT") or normalized.startswith("WITH")):
            return False
        blocked_keywords = ["INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "CREATE",
                            "TRUNCATE", "GRANT", "REVOKE"]
        for kw in blocked_keywords:
            if re.search(rf"\b{kw}\b", normalized):
                return False
        for pattern in self._BLOCKED_TABLES:
            if re.search(pattern, sql, re.IGNORECASE):
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
                table = arguments.get("table", "")
                for pattern in self._BLOCKED_TABLES:
                    if re.search(pattern, table, re.IGNORECASE):
                        return json.dumps({"error": "Query rejected: only SELECT statements allowed"})
                return self.mcp_client.call_tool("describe_table", arguments)
            else:
                return json.dumps({"error": f"Unknown tool: {tool_name}"})
        except Exception as e:
            logger.error(f"Tool call error ({tool_name}): {e}")
            return json.dumps({"error": f"Tool execution failed: {str(e)}"})

    def answer(self, question: str) -> dict[str, Any]:
        """Process a user question through the agent loop."""
        # Reject prompt injection attempts before touching the LLM
        if self._check_injection(question):
            logger.warning(f"Prompt injection attempt detected: {question[:80]}")
            return {
                "answer": "I can only answer questions about Service Express UK contract and customer data.",
                "tool_calls": [],
                "cached": False,
            }

        # Try direct answer first (bypass LLM for common queries)
        is_direct, direct_answer = try_direct_answer(question, self.mcp_client)
        if is_direct:
            logger.info(f"Direct answer for: {question[:50]}...")
            return {
                "answer": direct_answer,
                "tool_calls": [{"tool": "query", "pattern_matched": True}],
                "cached": True,
            }
        
        # Stable system prompt for KV cache reuse + examples in user message
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": EXAMPLES_CONTEXT + " " + question},
        ]

        tool_calls_log = []
        iterations = 0
        total_rejections = 0

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
                    extra_body={"cache_prompt": True, "n_keep": 150},
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

                if "Query rejected" in result:
                    total_rejections += 1
                    if total_rejections >= 2:
                        logger.warning("Aborting: repeated query rejections suggest prohibited access attempt")
                        return {
                            "answer": "I can only answer questions about Service Express UK contract and customer data.",
                            "tool_calls": tool_calls_log,
                        }

                tool_calls_log.append({
                    "tool": fn_name,
                    "arguments": fn_args,
                    "result_preview": result[:200] if len(result) > 200 else result,
                })

                try:
                    result_obj = json.loads(result)
                    cols = result_obj.get("columns", [])
                    rows = result_obj.get("rows", [])
                    if cols and rows:
                        compact = ",".join(cols) + "\n" + "\n".join(
                            ",".join(str(r.get(c, "")) for c in cols) for r in rows[:50]
                        )
                        result_for_llm = compact[:3000]
                    else:
                        result_for_llm = result[:3000]
                except Exception:
                    result_for_llm = result[:3000]

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result_for_llm,
                })

        # Hit max iterations
        return {
            "answer": "I reached the maximum number of queries while processing your question. Here's what I found so far based on the data retrieved.",
            "tool_calls": tool_calls_log,
            "warning": "Max tool calls reached",
        }

    def answer_stream(self, question: str):
        """Process a user question through the agent loop with streaming support.
        Uses non-streaming for tool-calling steps (llama.cpp limitation),
        then streams the final answer token-by-token.
        Yields SSE events: status updates, tool calls, and answer chunks."""
        import time

        # Reject prompt injection attempts before touching the LLM
        if self._check_injection(question):
            logger.warning(f"Prompt injection attempt detected (stream): {question[:80]}")
            safe_msg = "I can only answer questions about Service Express UK contract and customer data."
            yield f"event: answer\ndata: {json.dumps({'chunk': safe_msg, 'done': True})}\n\n"
            return

        # Try direct answer first (bypass LLM for common queries)
        is_direct, direct_answer = try_direct_answer(question, self.mcp_client)
        if is_direct:
            logger.info(f"Direct answer (streaming) for: {question[:50]}...")
            yield f"event: status\ndata: {json.dumps({'message': 'Found pre-built answer...'})}\n\n"
            yield f"event: answer\ndata: {json.dumps({'chunk': direct_answer, 'done': True})}\n\n"
            return

        # Stable system prompt for KV cache reuse + examples in user message
        messages = [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": EXAMPLES_CONTEXT + " " + question},
        ]

        tool_calls_log = []
        iterations = 0
        total_rejections = 0

        yield f"event: status\ndata: {json.dumps({'message': 'Thinking...'})}\n\n"

        while iterations < self.max_tool_calls:
            if len(messages) > 8:
                messages = messages[:2] + messages[-6:]
            iterations += 1

            tool_choice = "required" if iterations == 1 else "auto"

            try:
                yield f"event: status\ndata: {json.dumps({'message': f'Querying LLM (step {iterations})...'})}\n\n"

                # Run LLM call in a thread so we can send keepalive heartbeats
                import threading
                llm_result = {"response": None, "error": None}

                def _call_llm():
                    try:
                        llm_result["response"] = self.llm.chat.completions.create(
                            model=self.model,
                            messages=messages,
                            tools=TOOLS,
                            tool_choice=tool_choice,
                            temperature=0.1,
                            max_tokens=768,
                            extra_body={"cache_prompt": True, "n_keep": 150},
                        )
                    except Exception as e:
                        llm_result["error"] = e

                t = threading.Thread(target=_call_llm)
                t.start()

                # Send heartbeats every 10s while LLM is processing
                elapsed = 0
                while t.is_alive():
                    t.join(timeout=10)
                    if t.is_alive():
                        elapsed += 10
                        yield f": heartbeat {elapsed}s\n\n"
                        yield f"event: status\ndata: {json.dumps({'message': f'LLM processing (step {iterations}, {elapsed}s elapsed)...'})}\n\n"

                if llm_result["error"]:
                    raise llm_result["error"]

                response = llm_result["response"]

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

            # If no tool calls, stream the final answer
            if not message.tool_calls:
                answer = message.content or "I wasn't able to generate a response."
                # Stream in small chunks for progressive display
                chunk_size = 40
                for i in range(0, len(answer), chunk_size):
                    chunk = answer[i:i+chunk_size]
                    yield f"event: answer\ndata: {json.dumps({'chunk': chunk, 'done': i + chunk_size >= len(answer)})}\n\n"
                    time.sleep(0.03)
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

                yield f"event: status\ndata: {json.dumps({'message': f'Running {fn_name}...'})}\n\n"
                result = self._call_tool(fn_name, fn_args)
                logger.info(f"Tool result: {result[:300]}")

                if "Query rejected" in result:
                    total_rejections += 1
                    if total_rejections >= 2:
                        logger.warning("Aborting stream: repeated query rejections suggest prohibited access attempt")
                        safe_msg = "I can only answer questions about Service Express UK contract and customer data."
                        yield f"event: answer\ndata: {json.dumps({'chunk': safe_msg, 'done': True})}\n\n"
                        return

                tool_calls_log.append({
                    "tool": fn_name,
                    "arguments": fn_args,
                    "result_preview": result[:200] if len(result) > 200 else result,
                })

                try:
                    result_data = json.loads(result) if result.startswith('{') else {"result": result[:100]}
                except json.JSONDecodeError:
                    result_data = {"result": result[:100]}
                yield f"event: tool_result\ndata: {json.dumps({'tool': fn_name, 'result': result_data})}\n\n"

                # Compact the result for step-2: convert pretty JSON to compact CSV-style
                try:
                    result_obj = json.loads(result)
                    cols = result_obj.get("columns", [])
                    rows = result_obj.get("rows", [])
                    if cols and rows:
                        compact = ",".join(cols) + "\n" + "\n".join(
                            ",".join(str(r.get(c, "")) for c in cols) for r in rows[:50]
                        )
                        result_for_llm = compact[:3000]
                    else:
                        result_for_llm = result[:3000]
                except Exception:
                    result_for_llm = result[:3000]

                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": result_for_llm,
                })

        # Hit max iterations
        yield f"event: answer\ndata: {json.dumps({'chunk': 'I reached the maximum number of queries. Here is what I found:', 'done': False})}\n\n"
        yield f"event: answer\ndata: {json.dumps({'chunk': '', 'done': True})}\n\n"
