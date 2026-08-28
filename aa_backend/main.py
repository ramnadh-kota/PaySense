"""PaySense Account Aggregator backend boundary.

DELIBERATELY a SEPARATE service from ai_backend/main.py (the OpenAI proxy).
Account Aggregator secrets (a regulated AA/TSP's client credentials, FIU
registration details, encryption keys) must NEVER live alongside — or be
reachable through — the AI backend's config or code paths. This module is
where those secrets would be read from the environment once a real,
regulated AA/TSP is selected; it never does so today because none is
configured (see the PROVIDER SELECTION section below and README.md).

This backend is the ONLY thing the Flutter app is meant to call for AA
operations in production/sandbox mode — the app never talks to an AA/TSP
directly (see `lib/shared/services/account_aggregator/account_aggregator_network_client.dart`
on the Flutter side, which is the client of these exact routes).

Endpoints (mirroring PHASE B's requested surface):
    POST /aa/consent/initiate
    GET  /aa/consent/{connection_id}
    GET  /aa/accounts
    GET  /aa/transactions
    POST /aa/revoke

None of these currently reach a real AA/TSP. `AA_ENVIRONMENT` selects
between:
  - "mock"       (default) — deterministic in-memory data, safe for local
                  Flutter development against a real HTTP boundary instead
                  of the in-process MockAccountAggregatorProvider.
  - "production" — every route returns HTTP 501 with a clear, honest
                  message. There is no "sandbox" HTTP mode here because no
                  official AA/TSP sandbox API specification exists in this
                  repository to implement against (see README.md) — the
                  Flutter-side `SandboxAccountAggregatorProvider` already
                  covers that gap without needing a fabricated backend
                  contract to match against.
"""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

# ---------------------------------------------------------------------------
# Configuration — never a hardcoded secret. A real integration would also
# read a client secret / FIU credential here, from Secret Manager (or
# equivalent) at deploy time, exactly like ai_backend's OPENAI_API_KEY.
# None is read today because none is configured.
# ---------------------------------------------------------------------------

AA_ENVIRONMENT = os.environ.get("AA_ENVIRONMENT", "mock")  # "mock" | "production"
AA_PROVIDER_NAME = os.environ.get("AA_PROVIDER_NAME", "")  # e.g. "finvu" once selected — empty today

FORBIDDEN_KEY_FRAGMENTS = (
    "password",
    "passwd",
    "pin",
    "otp",
    "cvv",
    "cvc",
    "cardnumber",
    "secret",
    "token",
    "credential",
    "smsbody",
    "phone",
)


def _reject_forbidden_keys(value: object) -> None:
    """Recursively rejects any dict key that looks like a secret/credential
    — defense-in-depth mirroring ai_backend's own `_reject_forbidden_keys`,
    applied to every response this service builds before it's returned."""
    if isinstance(value, dict):
        for key, nested in value.items():
            lowered = str(key).lower().replace("_", "").replace("-", "")
            if any(fragment in lowered for fragment in FORBIDDEN_KEY_FRAGMENTS):
                raise ValueError(f"Response must not include field '{key}'")
            _reject_forbidden_keys(nested)
    elif isinstance(value, list):
        for item in value:
            _reject_forbidden_keys(item)


# ---------------------------------------------------------------------------
# DTOs — shaped to match the Flutter-side AccountAggregator* models
# (see lib/shared/services/account_aggregator/account_aggregator_models.dart)
# so the eventual real implementation is a drop-in, not a redesign.
# ---------------------------------------------------------------------------

InstitutionType = Literal["bank", "creditCard", "deposit", "loan", "mutualFund", "equity", "insurance", "pension", "other"]
ConnectionStatus = Literal[
    "disconnected", "initializing", "awaitingConsent", "consentGranted", "fetching",
    "syncing", "connected", "partiallyConnected", "failed", "revoked",
]
ConsentStatus = Literal["created", "pending", "approved", "rejected", "expired", "revoked"]


class ConsentInitiateRequest(BaseModel):
    user_id: str = Field(min_length=1)
    institution_types: list[InstitutionType] = Field(min_length=1)
    history_duration_days: int = Field(gt=0, le=3650)


class AccountDTO(BaseModel):
    id: str
    display_name: str
    institution_name: str
    institution_type: InstitutionType
    masked_identifier: str
    balance: float | None = None
    currency_code: str = "INR"
    last_synced_at: str | None = None
    status: ConnectionStatus = "connected"


class ConnectionDTO(BaseModel):
    connection_id: str
    provider_id: str
    provider_name: str
    status: ConnectionStatus
    consent_status: ConsentStatus
    created_at: str
    updated_at: str
    last_synced_at: str | None = None
    accounts: list[AccountDTO] = Field(default_factory=list)
    error_message: str | None = None


class TransactionDTO(BaseModel):
    id: str
    account_id: str
    amount: float
    direction: Literal["debit", "credit"]
    transaction_date: str
    narration: str | None = None
    reference_number: str | None = None
    mode: str | None = None
    currency_code: str = "INR"


class SyncResultDTO(BaseModel):
    connection_id: str
    synced_at: str
    accounts: list[AccountDTO]
    transactions_by_account_id: dict[str, list[TransactionDTO]]
    is_partial: bool = False
    warnings: list[str] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# In-memory mock store — AA_ENVIRONMENT=mock only. Deterministic, no
# persistence beyond process lifetime, mirrors the Flutter-side
# MockAccountAggregatorProvider's own HDFC/ICICI fixture data so a
# developer testing the Flutter app against this real HTTP boundary sees
# consistent data either way.
# ---------------------------------------------------------------------------

_connections: dict[str, ConnectionDTO] = {}
# Institution types requested at consent time, keyed by connection_id —
# stored explicitly rather than parsed back out of the connection_id
# string (fragile: user_id itself may contain hyphens).
_institution_types_by_connection: dict[str, list[str]] = {}


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def _mock_accounts_for(institution_types: list[str]) -> list[AccountDTO]:
    catalog = [
        AccountDTO(id="MOCK-ACC-HDFC-SAVINGS", display_name="HDFC Savings", institution_name="HDFC Bank",
                   institution_type="bank", masked_identifier="•••• 1234", balance=182450.0),
        AccountDTO(id="MOCK-ACC-ICICI-SAVINGS", display_name="ICICI Savings", institution_name="ICICI Bank",
                   institution_type="bank", masked_identifier="•••• 7821", balance=72300.0),
        AccountDTO(id="MOCK-ACC-HDFC-CREDITCARD", display_name="HDFC Credit Card", institution_name="HDFC Bank",
                   institution_type="creditCard", masked_identifier="•••• 4455", balance=18400.0),
        AccountDTO(id="MOCK-ACC-ICICI-PERSONALLOAN", display_name="ICICI Personal Loan", institution_name="ICICI Bank",
                   institution_type="loan", masked_identifier="•••• 9012", balance=482000.0),
    ]
    return [a for a in catalog if a.institution_type in institution_types]


def _require_mock_environment() -> None:
    if AA_ENVIRONMENT != "mock":
        raise HTTPException(
            status_code=501,
            detail=(
                "Real Account Aggregator integration is not yet configured. "
                "A regulated AA/TSP provider, FIU registration, and provider "
                "credentials are required before this endpoint can connect to a "
                "real bank. See aa_backend/README.md."
            ),
        )


app = FastAPI(title="PaySense Account Aggregator Backend")


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "environment": AA_ENVIRONMENT}


@app.post("/aa/consent/initiate", response_model=ConnectionDTO)
async def initiate_consent(payload: ConsentInitiateRequest) -> ConnectionDTO:
    _require_mock_environment()

    connection_id = f"mock-conn-{payload.user_id}-{'-'.join(sorted(payload.institution_types))}"
    now = _now_iso()
    connection = ConnectionDTO(
        connection_id=connection_id,
        provider_id="mock",
        provider_name="Sandbox / Mock Provider (Backend)",
        status="awaitingConsent",
        consent_status="pending",
        created_at=now,
        updated_at=now,
    )
    _connections[connection_id] = connection
    _institution_types_by_connection[connection_id] = list(payload.institution_types)
    _reject_forbidden_keys(connection.model_dump())
    return connection


@app.get("/aa/consent/{connection_id}", response_model=ConnectionDTO)
async def get_consent_status(connection_id: str) -> ConnectionDTO:
    _require_mock_environment()
    connection = _connections.get(connection_id)
    if connection is None:
        raise HTTPException(status_code=404, detail=f"No connection found for id '{connection_id}'.")
    return connection


@app.post("/aa/consent/{connection_id}/approve", response_model=ConnectionDTO)
async def dev_approve_consent(connection_id: str) -> ConnectionDTO:
    """DEV/TEST ONLY — mirrors the Flutter mock's `approveConsent` dev
    control. Never present in a real AA/TSP's API; only exists here so a
    developer can exercise the full HTTP round-trip locally."""
    _require_mock_environment()
    connection = _connections.get(connection_id)
    if connection is None:
        raise HTTPException(status_code=404, detail=f"No connection found for id '{connection_id}'.")
    if connection.consent_status != "pending":
        raise HTTPException(status_code=409, detail="Connection is not awaiting consent.")

    updated = connection.model_copy(update={
        "status": "consentGranted",
        "consent_status": "approved",
        "updated_at": _now_iso(),
    })
    _connections[connection_id] = updated
    return updated


@app.get("/aa/accounts", response_model=list[AccountDTO])
async def fetch_accounts(connection_id: str) -> list[AccountDTO]:
    _require_mock_environment()
    connection = _connections.get(connection_id)
    if connection is None:
        raise HTTPException(status_code=404, detail=f"No connection found for id '{connection_id}'.")
    if connection.consent_status != "approved":
        raise HTTPException(status_code=403, detail="Consent has not been approved yet.")

    requested_types = _institution_types_by_connection.get(connection_id, [])
    accounts = _mock_accounts_for(requested_types)
    _connections[connection_id] = connection.model_copy(update={"status": "fetching", "accounts": accounts})
    return accounts


@app.get("/aa/transactions", response_model=SyncResultDTO)
async def fetch_transactions(connection_id: str) -> SyncResultDTO:
    _require_mock_environment()
    connection = _connections.get(connection_id)
    if connection is None:
        raise HTTPException(status_code=404, detail=f"No connection found for id '{connection_id}'.")
    if connection.consent_status != "approved":
        raise HTTPException(status_code=403, detail="Consent has not been approved yet.")

    requested_types = _institution_types_by_connection.get(connection_id, [])
    accounts = _mock_accounts_for(requested_types)
    now = datetime.now(timezone.utc)

    transactions_by_account: dict[str, list[TransactionDTO]] = {}
    for account in accounts:
        if account.id == "MOCK-ACC-HDFC-SAVINGS":
            transactions_by_account[account.id] = [
                TransactionDTO(id="MOCK-HDFC-000001", account_id=account.id, amount=72000, direction="credit",
                                transaction_date=(now - timedelta(days=1)).isoformat(), narration="Salary",
                                reference_number="MOCK-HDFC-000001", mode="NEFT"),
                TransactionDTO(id="MOCK-HDFC-000004", account_id=account.id, amount=18000, direction="debit",
                                transaction_date=(now - timedelta(days=3)).isoformat(), narration="Rent",
                                reference_number="MOCK-HDFC-000004", mode="UPI"),
            ]
        else:
            transactions_by_account[account.id] = []

    result = SyncResultDTO(
        connection_id=connection_id,
        synced_at=_now_iso(),
        accounts=accounts,
        transactions_by_account_id=transactions_by_account,
    )
    _connections[connection_id] = connection.model_copy(update={
        "status": "connected",
        "accounts": accounts,
        "last_synced_at": result.synced_at,
        "updated_at": result.synced_at,
    })
    _reject_forbidden_keys(result.model_dump())
    return result


@app.post("/aa/revoke", response_model=ConnectionDTO)
async def revoke_consent(connection_id: str) -> ConnectionDTO:
    _require_mock_environment()
    connection = _connections.get(connection_id)
    if connection is None:
        raise HTTPException(status_code=404, detail=f"No connection found for id '{connection_id}'.")

    updated = connection.model_copy(update={
        "status": "revoked",
        "consent_status": "revoked",
        "updated_at": _now_iso(),
    })
    _connections[connection_id] = updated
    return updated
