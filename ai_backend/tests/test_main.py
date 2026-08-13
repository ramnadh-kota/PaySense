import os

import pytest
from fastapi.testclient import TestClient

import main


@pytest.fixture(autouse=True)
def _reset_rate_limit():
    main._request_log.clear()
    yield
    main._request_log.clear()


@pytest.fixture
def client():
    return TestClient(main.app)


SAMPLE_CONTEXT = {
    "fullName": "Test User",
    "monthlyIncome": 50000.0,
    "totalWalletBalance": 12000.0,
    "monthlyIncomeTotal": 50000.0,
    "monthlyExpenseTotal": 30000.0,
    "financialHealthScore": 72,
    "financialHealthStatus": "Good",
}


def _mock_openai_success(question, financial_context):
    return (
        '{"summary": "You are spending within your income this month.",'
        ' "key_insights": ["Expenses are 60% of income"],'
        ' "positive_trends": ["Savings rate is positive"],'
        ' "areas_to_improve": [],'
        ' "recommendations": ["Consider increasing your emergency fund"],'
        ' "warnings": []}'
    )


def test_valid_request_returns_structured_response(client, monkeypatch):
    monkeypatch.setattr(main, "call_openai", _mock_openai_success)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing financially?", "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 200
    body = response.json()
    for key in main.STRUCTURED_RESPONSE_KEYS:
        assert key in body
    assert body["summary"] == "You are spending within your income this month."
    assert body["key_insights"] == ["Expenses are 60% of income"]
    assert body["areas_to_improve"] == []


def test_missing_question_is_rejected(client):
    response = client.post("/v1/financial-analysis", json={"financial_context": SAMPLE_CONTEXT})
    assert response.status_code == 422


def test_empty_question_is_rejected(client):
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "   ", "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 422


def test_oversized_question_is_rejected(client):
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "a" * (main.MAX_QUESTION_LENGTH + 1), "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 422


def test_empty_financial_context_is_rejected(client):
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": {}},
    )
    assert response.status_code == 422


def test_missing_financial_context_is_rejected(client):
    response = client.post("/v1/financial-analysis", json={"question": "How am I doing?"})
    assert response.status_code == 422


@pytest.mark.parametrize(
    "forbidden_key",
    ["password", "pin", "pinHash", "biometricToken", "apiKey", "authToken", "sessionSecret"],
)
def test_sensitive_fields_are_rejected(client, forbidden_key):
    context = dict(SAMPLE_CONTEXT)
    context[forbidden_key] = "should-not-be-sent"
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": context},
    )
    assert response.status_code == 422


def test_oversized_financial_context_is_rejected(client):
    context = dict(SAMPLE_CONTEXT)
    context["recentTransactionsSummary"] = "x" * (main.MAX_CONTEXT_BYTES + 1)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": context},
    )
    assert response.status_code == 422


def test_malformed_openai_response_returns_controlled_error(client, monkeypatch):
    monkeypatch.setattr(main, "call_openai", lambda q, c: "not json at all")
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 502
    assert "not json at all" not in response.text


def test_openai_timeout_returns_504(client, monkeypatch):
    def _raise_timeout(question, financial_context):
        raise main.OpenAiError("OpenAI request timed out.", 504)

    monkeypatch.setattr(main, "call_openai", _raise_timeout)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 504


def test_openai_rate_limit_returns_429(client, monkeypatch):
    def _raise_rate_limit(question, financial_context):
        raise main.OpenAiError("OpenAI rate limit reached.", 429)

    monkeypatch.setattr(main, "call_openai", _raise_rate_limit)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 429


def test_openai_5xx_error_returns_502(client, monkeypatch):
    def _raise_generic(question, financial_context):
        raise main.OpenAiError("OpenAI request failed.", 502)

    monkeypatch.setattr(main, "call_openai", _raise_generic)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": SAMPLE_CONTEXT},
    )
    assert response.status_code == 502


def test_response_never_contains_api_key(client, monkeypatch):
    monkeypatch.setattr(main, "call_openai", _mock_openai_success)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": SAMPLE_CONTEXT},
    )
    assert os.environ["OPENAI_API_KEY"] not in response.text


def test_error_response_never_contains_api_key(client, monkeypatch):
    def _raise_generic(question, financial_context):
        raise main.OpenAiError("OpenAI request failed.", 502)

    monkeypatch.setattr(main, "call_openai", _raise_generic)
    response = client.post(
        "/v1/financial-analysis",
        json={"question": "How am I doing?", "financial_context": SAMPLE_CONTEXT},
    )
    assert os.environ["OPENAI_API_KEY"] not in response.text


def test_local_rate_limiter_blocks_after_threshold(client, monkeypatch):
    monkeypatch.setattr(main, "call_openai", _mock_openai_success)
    for _ in range(main.RATE_LIMIT_MAX_REQUESTS):
        r = client.post(
            "/v1/financial-analysis",
            json={"question": "hi", "financial_context": SAMPLE_CONTEXT},
        )
        assert r.status_code == 200
    r = client.post(
        "/v1/financial-analysis",
        json={"question": "hi", "financial_context": SAMPLE_CONTEXT},
    )
    assert r.status_code == 429


def test_parse_structured_response_normalizes_missing_fields():
    result = main.parse_structured_response('{"summary": "ok"}')
    assert result.summary == "ok"
    assert result.key_insights == []
    assert result.positive_trends == []
    assert result.warnings == []


def test_parse_structured_response_drops_non_string_list_items():
    result = main.parse_structured_response(
        '{"summary": "ok", "key_insights": ["fine", 123, null, "also fine"]}'
    )
    assert result.key_insights == ["fine", "also fine"]


def test_parse_structured_response_strips_markdown_fence():
    result = main.parse_structured_response('```json\n{"summary": "ok"}\n```')
    assert result.summary == "ok"


def test_parse_structured_response_rejects_non_object_json():
    with pytest.raises(main.OpenAiError):
        main.parse_structured_response("[1, 2, 3]")


def test_parse_structured_response_rejects_unparseable_text():
    with pytest.raises(main.OpenAiError):
        main.parse_structured_response("this is not json and not fenced either")


def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
