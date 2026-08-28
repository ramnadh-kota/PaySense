from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["environment"] == "mock"


def test_consent_lifecycle_end_to_end():
    initiate = client.post(
        "/aa/consent/initiate",
        json={"user_id": "test-user", "institution_types": ["bank"], "history_duration_days": 180},
    )
    assert initiate.status_code == 200
    connection = initiate.json()
    assert connection["status"] == "awaitingConsent"
    assert connection["consent_status"] == "pending"
    connection_id = connection["connection_id"]

    # Never automatically approved.
    status = client.get(f"/aa/consent/{connection_id}")
    assert status.json()["consent_status"] == "pending"

    # Accounts are blocked before approval.
    blocked = client.get("/aa/accounts", params={"connection_id": connection_id})
    assert blocked.status_code == 403

    approved = client.post(f"/aa/consent/{connection_id}/approve")
    assert approved.status_code == 200
    assert approved.json()["consent_status"] == "approved"

    accounts = client.get("/aa/accounts", params={"connection_id": connection_id})
    assert accounts.status_code == 200
    assert len(accounts.json()) > 0
    assert any(a["institution_name"] == "HDFC Bank" for a in accounts.json())

    sync = client.get("/aa/transactions", params={"connection_id": connection_id})
    assert sync.status_code == 200
    assert sync.json()["accounts"]

    revoked = client.post("/aa/revoke", params={"connection_id": connection_id})
    assert revoked.status_code == 200
    assert revoked.json()["consent_status"] == "revoked"


def test_unknown_connection_returns_404():
    response = client.get("/aa/consent/does-not-exist")
    assert response.status_code == 404


def test_double_approval_is_rejected():
    initiate = client.post(
        "/aa/consent/initiate",
        json={"user_id": "test-user-2", "institution_types": ["bank"], "history_duration_days": 90},
    )
    connection_id = initiate.json()["connection_id"]
    client.post(f"/aa/consent/{connection_id}/approve")
    second_attempt = client.post(f"/aa/consent/{connection_id}/approve")
    assert second_attempt.status_code == 409


def test_response_never_contains_a_forbidden_field(monkeypatch):
    initiate = client.post(
        "/aa/consent/initiate",
        json={"user_id": "test-user-3", "institution_types": ["bank"], "history_duration_days": 180},
    )
    connection_id = initiate.json()["connection_id"]
    client.post(f"/aa/consent/{connection_id}/approve")
    sync = client.get("/aa/transactions", params={"connection_id": connection_id})
    serialized = str(sync.json()).lower()
    for fragment in ["password", "otp", "cvv", "secret", "token", "credential"]:
        assert fragment not in serialized


def test_production_environment_never_serves_mock_data(monkeypatch):
    import main

    monkeypatch.setattr(main, "AA_ENVIRONMENT", "production")
    response = client.post(
        "/aa/consent/initiate",
        json={"user_id": "test-user-4", "institution_types": ["bank"], "history_duration_days": 180},
    )
    assert response.status_code == 501
    assert "not yet configured" in response.json()["detail"].lower()
