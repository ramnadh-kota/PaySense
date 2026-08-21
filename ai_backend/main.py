"""PaySense AI backend — a thin, stateless proxy between the Flutter app and
the OpenAI API.

The OpenAI API key is read from the environment (populated by Cloud Run from
Secret Manager at deploy time — see README.md). It is never logged, never
echoed back in a response, and never embedded in client code.
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import time
from collections import defaultdict, deque
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field, field_validator
from starlette.responses import JSONResponse

logger = logging.getLogger("paysense_ai_backend")
logging.basicConfig(level=logging.INFO)

# ---------------------------------------------------------------------------
# Configuration (all overridable via environment variables at deploy time)
# ---------------------------------------------------------------------------

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-5.6-terra")
OPENAI_TIMEOUT_SECONDS = float(os.environ.get("OPENAI_TIMEOUT_SECONDS", "20"))
OPENAI_MAX_OUTPUT_TOKENS = int(os.environ.get("OPENAI_MAX_OUTPUT_TOKENS", "1024"))

MAX_QUESTION_LENGTH = 500
MAX_CONTEXT_BYTES = 20_000
MAX_REQUEST_BODY_BYTES = 50_000
RATE_LIMIT_MAX_REQUESTS = int(os.environ.get("RATE_LIMIT_MAX_REQUESTS", "10"))
RATE_LIMIT_WINDOW_SECONDS = 60

# Keys that must never appear in a financial_context payload. The Flutter
# client's FinancialContext model never collects these, but this check is
# defense-in-depth against a modified or compromised client.
FORBIDDEN_CONTEXT_KEY_FRAGMENTS = (
    "password",
    "pin",
    "biometric",
    "token",
    "secret",
    "apikey",
    "credential",
)

STRUCTURED_RESPONSE_KEYS = (
    "summary",
    "key_insights",
    "positive_trends",
    "areas_to_improve",
    "recommendations",
    "warnings",
)

SYSTEM_INSTRUCTION = """You are the PaySense AI Financial Assistant, built into the PaySense personal finance app.

Rules you must always follow:
- Base your analysis ONLY on the financial_context JSON supplied in the user message. Never invent transactions, balances, income, expenses, or percentages that are not present or directly derivable from that data.
- If information needed to answer is not present in financial_context, say so plainly instead of guessing.
- When financial_context already includes a calculated figure (e.g. under planningContext, safeToSpendContext, cashFlowContext, subscriptionsContext, reportsContext) — such as a readiness score, safe-to-spend amount, emergency fund projection, or a "what if" scenario result — use that figure directly. Never recompute your own estimate of something PaySense has already calculated, and never state a number that conflicts with one already present in financial_context.
- Clearly distinguish factual statements (from the data) from your own recommendations, and clearly label any forward-looking projection (e.g. "based on your current savings rate, you could potentially...") as an estimate, never as a guaranteed outcome.
- Use simple, plain language. Avoid judgmental or shaming language about spending habits. Always express money amounts in Indian Rupees (₹) and prefer Indian financial terminology (e.g. "EMI", "lakh"/"crore" where natural) over generic terms.
- You are NOT a licensed financial advisor. Never claim to be one, never guarantee investment returns, and never recommend specific high-risk investments (stocks, crypto, leveraged products, etc.).
- You are advisory only: you can never create, modify, or execute a transaction, transfer, bill payment, EMI payment, or balance change, and no such action is ever performed as a result of this conversation. If the user asks you to perform one (e.g. "transfer ₹5,000 to my SBI account", "pay this bill"), clearly explain that you can't take financial actions through chat and point them to the relevant screen in the app instead. Never say or imply that you performed, scheduled, or confirmed any such action.
- You may discuss general tax concepts (e.g. what a deduction is, how slabs work). When financial_context includes a taxScenario, that figure came from PaySense's own deterministic Tax Calculator (FY 2026-27 rules) — explain and contextualize it, but NEVER invent a tax slab, deduction, or eligibility rule, never independently compute or restate a different tax figure, never claim an exact liability when taxScenario is absent, never claim a guaranteed refund (only ever "estimated excess TDS"), and never claim an ITR was filed or can be filed through PaySense — PaySense has no ITR-filing or tax-portal capability.
- When financial_context includes an affordabilityScenario, that verdict (comfortable / possible / risky / not recommended / insufficient data) came from PaySense's own deterministic Affordability Calculator — explain and contextualize it using exactly that status language, but NEVER independently judge or restate a different affordability verdict, NEVER say "buy it", "go ahead", or similar authorization language, and NEVER guarantee "you can afford it" — affordability is never financial authorization. Always frame it as "Based on the information currently available...". If financial_context has no affordabilityScenario but the user is asking about a specific purchase, say plainly that you don't have enough information rather than guessing.
- When financial_context includes financialHealthTrendsContext, every score/percentage/direction (improving/declining/stable/insufficientData) there came from PaySense's own deterministic Financial Health Trends Calculator — use those figures and that exact direction language to answer questions like "am I doing better financially?" or "why is my financial health declining?", but NEVER recompute a trend yourself, NEVER invent a historical figure not present in the data, and NEVER claim a trend exists when a domain's direction is "insufficientData" — say plainly that PaySense doesn't have enough history for that yet instead.
- Encourage the user to verify important financial decisions with a qualified professional before acting on them.
- Respond ONLY with a single JSON object matching this exact schema — no prose outside the JSON, no markdown fences:
{
  "summary": "2-3 sentence plain-language summary relevant to the user's question",
  "key_insights": ["short factual observation", "..."],
  "positive_trends": ["short positive observation - omit the array entry if none"],
  "areas_to_improve": ["short area needing attention - omit if none"],
  "recommendations": ["short actionable suggestion", "..."],
  "warnings": ["short warning, e.g. overdue bills or negative balance - omit if none"]
}
Keep each list item under 200 characters. Keep the whole response concise."""


# ---------------------------------------------------------------------------
# Request / response models
# ---------------------------------------------------------------------------


class FinancialAnalysisRequest(BaseModel):
    question: str = Field(min_length=1, max_length=MAX_QUESTION_LENGTH)
    financial_context: dict[str, Any]

    @field_validator("question")
    @classmethod
    def question_must_not_be_blank(cls, value: str) -> str:
        stripped = value.strip()
        if not stripped:
            raise ValueError("question must not be blank")
        return stripped

    @field_validator("financial_context")
    @classmethod
    def context_must_be_safe(cls, value: dict[str, Any]) -> dict[str, Any]:
        if not value:
            raise ValueError("financial_context must not be empty")

        serialized_size = len(json.dumps(value).encode("utf-8"))
        if serialized_size > MAX_CONTEXT_BYTES:
            raise ValueError("financial_context is too large")

        _reject_forbidden_keys(value)
        return value


def _reject_forbidden_keys(value: Any) -> None:
    """Recursively rejects any dict key that looks like a secret/credential."""
    if isinstance(value, dict):
        for key, nested in value.items():
            lowered = str(key).lower().replace("_", "").replace("-", "")
            if any(fragment in lowered for fragment in FORBIDDEN_CONTEXT_KEY_FRAGMENTS):
                raise ValueError(f"financial_context must not include field '{key}'")
            _reject_forbidden_keys(nested)
    elif isinstance(value, list):
        for item in value:
            _reject_forbidden_keys(item)


class FinancialAnalysisResponse(BaseModel):
    summary: str
    key_insights: list[str]
    positive_trends: list[str]
    areas_to_improve: list[str]
    recommendations: list[str]
    warnings: list[str]


# ---------------------------------------------------------------------------
# Minimal in-memory, single-instance rate limiter.
#
# Intentionally simple: per-process, keyed by client IP, fixed window. It does
# not coordinate across Cloud Run instances. This is a basic abuse safeguard,
# not a production-grade rate limiter — see README "Security considerations".
# ---------------------------------------------------------------------------

_request_log: dict[str, deque[float]] = defaultdict(deque)


def _check_rate_limit(client_id: str) -> None:
    now = time.monotonic()
    log = _request_log[client_id]
    while log and now - log[0] > RATE_LIMIT_WINDOW_SECONDS:
        log.popleft()
    if len(log) >= RATE_LIMIT_MAX_REQUESTS:
        raise HTTPException(status_code=429, detail="Too many requests. Please try again shortly.")
    log.append(now)


# ---------------------------------------------------------------------------
# OpenAI client
# ---------------------------------------------------------------------------


class OpenAiError(Exception):
    """Raised for any OpenAI-side failure. `status_code` is the HTTP status
    this backend should return to the caller for this failure."""

    def __init__(self, message: str, status_code: int = 502):
        super().__init__(message)
        self.status_code = status_code


def _get_openai_client():
    # Imported lazily so the rest of the app (and most tests) can run without
    # the openai package needing valid credentials at import time.
    from openai import OpenAI

    if not OPENAI_API_KEY:
        raise OpenAiError("OpenAI API key is not configured on the server.", 500)
    return OpenAI(api_key=OPENAI_API_KEY)


# Structured-output config for the Responses API: passed as the `text`
# argument to client.responses.create(). `strict: True` requires every
# property to be listed in `required` and forbids extras, matching the
# response contract this backend guarantees to Flutter.
_RESPONSE_TEXT_FORMAT = {
    "format": {
        "type": "json_schema",
        "name": "financial_analysis",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "key_insights": {"type": "array", "items": {"type": "string"}},
                "positive_trends": {"type": "array", "items": {"type": "string"}},
                "areas_to_improve": {"type": "array", "items": {"type": "string"}},
                "recommendations": {"type": "array", "items": {"type": "string"}},
                "warnings": {"type": "array", "items": {"type": "string"}},
            },
            "required": [
                "summary",
                "key_insights",
                "positive_trends",
                "areas_to_improve",
                "recommendations",
                "warnings",
            ],
            "additionalProperties": False,
        },
    },
}


def call_openai(question: str, financial_context: dict[str, Any]) -> str:
    """Calls OpenAI's Responses API and returns the raw text of its response.

    Isolated into a single function so it is trivial to monkeypatch in tests,
    and so the exact SDK call can be reviewed/updated independently of the
    request-handling logic below. Verify this against the current OpenAI API
    docs (https://platform.openai.com/docs) before deploying, since SDK
    method signatures and structured-output mechanisms evolve.

    Each call is a single, stateless, single-turn request: `store=False` so
    OpenAI does not retain the (financial) request/response server-side, and
    no `previous_response_id`/conversation is used, since this backend has no
    need to reference this exchange again — the full financial_context is
    already resent by Flutter on every question.
    """
    client = _get_openai_client()

    user_content = (
        f"User question: {question}\n\n"
        "financial_context (JSON, authoritative — do not use any figures not "
        f"present here):\n{json.dumps(financial_context)}"
    )

    try:
        response = client.responses.create(
            model=OPENAI_MODEL,
            input=[
                {"role": "system", "content": SYSTEM_INSTRUCTION},
                {"role": "user", "content": user_content},
            ],
            max_output_tokens=OPENAI_MAX_OUTPUT_TOKENS,
            temperature=0.3,
            store=False,
            text=_RESPONSE_TEXT_FORMAT,
        )
    except Exception as exc:  # noqa: BLE001 - normalized into OpenAiError below
        status = getattr(exc, "status_code", None) or getattr(exc, "http_status", None)
        message = str(exc)
        lowered = message.lower()
        if status == 429 or "429" in message or "rate_limit" in lowered or "rate limit" in lowered:
            raise OpenAiError("OpenAI rate limit reached.", 429) from exc
        if "timeout" in lowered or "timed out" in lowered:
            raise OpenAiError("OpenAI request timed out.", 504) from exc
        logger.warning("OpenAI call failed: %s", type(exc).__name__)
        raise OpenAiError("OpenAI request failed.", 502) from exc

    text = getattr(response, "output_text", None)
    if not text:
        raise OpenAiError("OpenAI returned an empty response.", 502)
    return text


def parse_structured_response(raw_text: str) -> FinancialAnalysisResponse:
    """Parses and normalizes the model's JSON text into the response contract.

    Never trusts the provider's output shape blindly: missing fields default
    to empty, unexpected types are dropped, and anything that cannot be
    interpreted unambiguously raises OpenAiError so the caller returns a
    controlled error instead of a malformed payload.
    """
    try:
        data = json.loads(raw_text)
    except json.JSONDecodeError:
        # Narrow, unambiguous recovery: the model occasionally wraps JSON in
        # a markdown code fence despite instructions not to.
        stripped = raw_text.strip()
        if stripped.startswith("```"):
            stripped = stripped.strip("`")
            if stripped.lower().startswith("json"):
                stripped = stripped[4:].strip()
            try:
                data = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise OpenAiError("OpenAI returned malformed output.", 502) from exc
        else:
            raise OpenAiError("OpenAI returned malformed output.", 502)

    if not isinstance(data, dict):
        raise OpenAiError("OpenAI returned malformed output.", 502)

    def _str(value: Any) -> str:
        return value.strip() if isinstance(value, str) else ""

    def _str_list(value: Any) -> list[str]:
        if not isinstance(value, list):
            return []
        return [item.strip() for item in value if isinstance(item, str) and item.strip()][:10]

    return FinancialAnalysisResponse(
        summary=_str(data.get("summary")),
        key_insights=_str_list(data.get("key_insights")),
        positive_trends=_str_list(data.get("positive_trends")),
        areas_to_improve=_str_list(data.get("areas_to_improve")),
        recommendations=_str_list(data.get("recommendations")),
        warnings=_str_list(data.get("warnings")),
    )


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(title="PaySense AI Backend")

# The mobile app has no browser origin, but the Flutter project also targets
# web; CORS is left open at the HTTP layer since there is no user-specific
# session here. Reassess if/when per-user auth is added (see README).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type"],
)


@app.middleware("http")
async def limit_body_size(request: Request, call_next):
    content_length = request.headers.get("content-length")
    if content_length is not None and int(content_length) > MAX_REQUEST_BODY_BYTES:
        return JSONResponse(status_code=413, content={"detail": "Request body too large."})
    return await call_next(request)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/financial-analysis", response_model=FinancialAnalysisResponse)
async def financial_analysis(payload: FinancialAnalysisRequest, request: Request) -> FinancialAnalysisResponse:
    client_id = request.client.host if request.client else "unknown"
    _check_rate_limit(client_id)

    try:
        raw_text = await asyncio.wait_for(
            asyncio.to_thread(call_openai, payload.question, payload.financial_context),
            timeout=OPENAI_TIMEOUT_SECONDS,
        )
        return parse_structured_response(raw_text)
    except asyncio.TimeoutError as exc:
        logger.warning("financial_analysis timed out after %ss", OPENAI_TIMEOUT_SECONDS)
        raise HTTPException(status_code=504, detail="OpenAI request timed out.") from exc
    except OpenAiError as exc:
        logger.warning("financial_analysis failed: %s", exc)
        raise HTTPException(status_code=exc.status_code, detail=str(exc)) from exc
