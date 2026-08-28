# PaySense Account Aggregator Backend

A **separate** backend service from `ai_backend/` (the OpenAI proxy). This
exists specifically so Account Aggregator credentials/secrets are never
mixed into the AI proxy's configuration or code paths, per PaySense's
explicit security rule: AA secrets and AI secrets must never share a
service boundary.

## What this is today

A **mock-only** HTTP boundary. `AA_ENVIRONMENT=mock` (the default) serves
deterministic, in-memory test data — no real bank, no real AA/TSP, no
network call outside this process. `AA_ENVIRONMENT=production` makes every
route return `501 Not Implemented` with an honest message, rather than
silently serving mock data under a "production" label.

**This service has never been connected to a real, regulated Account
Aggregator / TSP.** Nothing here should be represented to end users (or in
any release notes) as real bank connectivity.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| POST | `/aa/consent/initiate` | Start a consent request |
| GET | `/aa/consent/{id}` | Poll consent/connection status |
| POST | `/aa/consent/{id}/approve` | **Dev/test only** — simulates approval (mock mode only, never in a real provider's API) |
| GET | `/aa/accounts?connection_id=...` | List discovered accounts (requires approved consent) |
| GET | `/aa/transactions?connection_id=...` | Sync balances + transactions (requires approved consent) |
| POST | `/aa/revoke?connection_id=...` | Revoke consent |

Request/response shapes intentionally mirror the Flutter-side
`AccountAggregatorConnection`/`AccountAggregatorAccount`/
`AccountAggregatorTransaction`/`AccountAggregatorSyncResult` models
(`lib/shared/services/account_aggregator/account_aggregator_models.dart`)
so that swapping the mock implementation for a real one later should not
require changing these DTOs' shape.

## What is required to connect a REAL Account Aggregator

None of the following exists in this repository, and none of it is
fabricated here:

1. **A regulated AA/TSP partner** (e.g. Finvu, OneMoney, or another entity
   licensed as an Account Aggregator/Technical Service Provider by the RBI)
   — an actual commercial/legal onboarding relationship must exist first.
2. **FIU registration with Sahamati** — PaySense must be registered as a
   Financial Information User in India's AA ecosystem before it can
   request consent from a real user.
3. **Provider API credentials** — issued by the chosen AA/TSP after
   onboarding (client id + client secret, or equivalent). These must be
   stored in a secret manager (e.g. Google Secret Manager, matching
   `ai_backend`'s own `OPENAI_API_KEY` pattern) and injected as environment
   variables at deploy time — **never** committed to source control, never
   embedded in the Flutter app.
4. **ReBIT-compliant encryption** — the AA API specification (published by
   ReBIT) mandates ECDH key exchange + AES-GCM for decrypting Financial
   Information payloads. This is non-trivial cryptography that must be
   implemented against the ACTUAL published spec, not guessed at.
5. **The provider's real base URL and API contract** — `AA_BASE_URL` below
   is a placeholder; the real value and exact request/response schema come
   from the chosen AA/TSP's own API documentation once contracted.

## Configuration

All environment-driven, mirroring `ai_backend`'s convention — nothing here
is hardcoded:

| Variable | Purpose | Default |
|---|---|---|
| `AA_ENVIRONMENT` | `mock` or `production` | `mock` |
| `AA_PROVIDER_NAME` | The contracted AA/TSP's name, once selected | *(empty)* |
| `PORT` | HTTP port (matches `ai_backend`'s own `PORT` convention) | `8081` |

Once a real provider is selected, this file's "production" branch would
also need (not present today): `AA_CLIENT_ID`, `AA_CLIENT_SECRET` (from
Secret Manager, never a plain env var in source), `AA_BASE_URL`, and
whatever encryption key material the provider's spec requires.

## Local development

```bash
pip install -r requirements-dev.txt
uvicorn main:app --reload --port 8081
```

## Running tests

```bash
pytest
```
