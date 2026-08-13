# PaySense AI Backend

A minimal, stateless FastAPI service that proxies financial-analysis requests
from the PaySense Flutter app to the OpenAI API. It exists for one reason:
**the OpenAI API key must never be embedded in the Android/iOS app**, since
anything shipped in an APK/IPA can be extracted. This service is the only
thing that holds the key, and it holds it only in memory, read from the
environment at process start.

```
Flutter app  --HTTPS-->  Cloud Run (this service)  --HTTPS-->  OpenAI API
```

## Endpoint

### `POST /v1/financial-analysis`

Request:

```json
{
  "question": "How can I save more this month?",
  "financial_context": { "...": "aggregated fields from PaySense's existing FinancialContext" }
}
```

Response (always this shape on success — the provider's raw output is never
returned directly):

```json
{
  "summary": "...",
  "key_insights": ["..."],
  "positive_trends": ["..."],
  "areas_to_improve": ["..."],
  "recommendations": ["..."],
  "warnings": ["..."]
}
```

### `GET /health`

Liveness check for Cloud Run. Returns `{"status": "ok"}`.

## Request validation / abuse safeguards

- `question`: 1–500 characters, rejected otherwise (422).
- `financial_context`: must be non-empty, capped at ~20KB serialized, and is
  scanned (recursively) for key names that look like credentials
  (`password`, `pin`, `biometric`, `token`, `secret`, `apikey`,
  `credential`) — the request is rejected (422) if any are present. This is
  defense-in-depth; the Flutter client's `FinancialContext` model never
  collects these fields in the first place.
- Total request body capped at ~50KB (413 if exceeded, checked via
  `Content-Length`).
- A single OpenAI call has a 20s timeout (`OPENAI_TIMEOUT_SECONDS`,
  configurable) and a bounded output size (`OPENAI_MAX_OUTPUT_TOKENS`).
- A minimal in-memory, per-IP, fixed-window rate limiter
  (`RATE_LIMIT_MAX_REQUESTS` per `RATE_LIMIT_WINDOW_SECONDS`, default
  10/minute). **This is process-local** — it does not coordinate across
  Cloud Run instances or survive a restart, and it is not a substitute for
  real abuse protection at scale. For production-grade rate limiting, put
  this service behind Cloud Armor or API Gateway with its own quota policy.
- There is currently no per-user authentication in front of this endpoint —
  see "Security considerations" below before treating it as production-hardened.

## OpenAI configuration

| Env var | Default | Purpose |
|---|---|---|
| `OPENAI_API_KEY` | *(required)* | Read from Google Secret Manager at deploy time (mounted into Cloud Run as an env var — see "Deployment" below). Never logged, never returned. |
| `OPENAI_MODEL` | `gpt-5.6-terra` | Model id. Confirmed current/GA against [OpenAI's model and pricing docs](https://platform.openai.com/docs/models) as of 2026-08-13 — the GPT-5.6 family's mid-tier, described by OpenAI as balancing intelligence and cost, which fits short financial-analysis/chat responses better than the flagship `gpt-5.6-sol` tier. **Verify this is still current** before deploying — model names change over time and this default may age. |
| `OPENAI_TIMEOUT_SECONDS` | `20` | Hard timeout for a single OpenAI call. |
| `OPENAI_MAX_OUTPUT_TOKENS` | `1024` | Output cap passed to OpenAI. |
| `RATE_LIMIT_MAX_REQUESTS` | `10` | Requests per IP per window. |

The exact OpenAI SDK call lives in a single function, `call_openai()` in
`main.py`, specifically so it's easy to review or adjust independently of
request handling if the `openai` SDK surface changes. It uses the
**OpenAI Responses API** (`client.responses.create(...)`), not Chat
Completions. Structured output is requested via the Responses API's
`text.format` configuration:

```python
response = client.responses.create(
    model=OPENAI_MODEL,
    input=[
        {"role": "system", "content": SYSTEM_INSTRUCTION},
        {"role": "user", "content": user_content},
    ],
    max_output_tokens=OPENAI_MAX_OUTPUT_TOKENS,
    store=False,
    text={
        "format": {
            "type": "json_schema",
            "name": "financial_analysis",
            "strict": True,
            "schema": { ... },  # the six response fields below
        },
    },
)
```

`store=False` is set deliberately: each call is a single, stateless,
one-off request — OpenAI does not retain the (financial) request/response
server-side, and no `previous_response_id`/conversation mechanism is used,
since the full `financial_context` is already resent by Flutter on every
question. The response text is read via `response.output_text`.

Re-check this against current OpenAI docs before deploying, since the
Responses API's structured-output mechanism can evolve across API
generations.

## Local development

```bash
cd ai_backend
python -m venv .venv
source .venv/bin/activate   # or .venv\Scripts\activate on Windows
pip install -r requirements-dev.txt

export OPENAI_API_KEY=your-local-dev-key   # never commit this
uvicorn main:app --reload --port 8080
```

Then:

```bash
curl -X POST http://localhost:8080/v1/financial-analysis \
  -H "Content-Type: application/json" \
  -d '{"question": "How am I doing financially?", "financial_context": {"monthlyIncome": 50000}}'
```

## Running tests

```bash
cd ai_backend
pip install -r requirements-dev.txt
pytest
```

Tests never call the real OpenAI API — `call_openai` is monkeypatched in
every test, and `OPENAI_API_KEY` is set to an obviously-fake value
(`test-key-not-real`) purely so the module can import.

## Deployment (Google Cloud)

This is conceptual — no commands here have been run against a real project.
Replace every `PLACEHOLDER` below with your own values.

### 1. Create OpenAI API access

Create an API key at [platform.openai.com](https://platform.openai.com/api-keys),
scoped to a project dedicated to this backend if your OpenAI org supports it.

### 2. Store it in Secret Manager

```bash
gcloud secrets create OPENAI_API_KEY_SECRET \
  --project=PROJECT_ID \
  --replication-policy=automatic

echo -n "PASTE_YOUR_KEY_HERE" | gcloud secrets versions add OPENAI_API_KEY_SECRET \
  --project=PROJECT_ID \
  --data-file=-
```

Do this from your own terminal — never paste the key into a chat/AI session
or into a file that gets committed.

### 3. Grant the Cloud Run service account access

```bash
gcloud secrets add-iam-policy-binding OPENAI_API_KEY_SECRET \
  --project=PROJECT_ID \
  --member="serviceAccount:SERVICE_ACCOUNT_EMAIL" \
  --role="roles/secretmanager.secretAccessor"
```

`SERVICE_ACCOUNT_EMAIL` is typically the Cloud Run service's runtime service
account (defaults to the project's compute service account unless you
configure a dedicated one — a dedicated least-privilege service account is
recommended).

### 4. Deploy to Cloud Run, mounting the secret as an env var

```bash
gcloud run deploy SERVICE_NAME \
  --project=PROJECT_ID \
  --region=REGION \
  --source=ai_backend \
  --allow-unauthenticated \
  --set-secrets=OPENAI_API_KEY=OPENAI_API_KEY_SECRET:latest \
  --set-env-vars=OPENAI_MODEL=gpt-5.6-terra
```

Cloud Run injects the secret's value into the `OPENAI_API_KEY` environment
variable at container start — the key is never baked into the image and
never appears in `gcloud` output or logs.

`--allow-unauthenticated` is used here because the mobile app calls this
endpoint directly with no user-specific credential yet (see "Security
considerations"). If you add authentication in front of this service later,
drop this flag.

### 5. Configure the Flutter app with the resulting URL

`gcloud run deploy` prints a `https://SERVICE_NAME-xxxxx-REGION.a.run.app`
URL. That URL is **not a secret** — pass it to Flutter at build/run time:

```bash
flutter run --dart-define=AI_BACKEND_BASE_URL=https://SERVICE_NAME-xxxxx-REGION.a.run.app
flutter build apk --dart-define=AI_BACKEND_BASE_URL=https://SERVICE_NAME-xxxxx-REGION.a.run.app
```

See `lib/core/config/ai_backend_config.dart` — if this isn't set, AI chat
requests fail cleanly and the app falls back to local Financial Health
insights; nothing crashes.

## Security considerations

- **No end-user auth in front of this endpoint yet.** Anyone with the Cloud
  Run URL can call it (rate-limited, but only loosely). Before wider release,
  consider: Firebase App Check (attests the request comes from a genuine
  PaySense app build), or a lightweight per-installation token issued by the
  app. This was intentionally left out per the current scope — "do not
  implement an elaborate authentication system yet."
- **The in-memory rate limiter is not abuse-proof.** It resets on every
  deploy/restart and doesn't share state across concurrent instances. It
  will not stop a distributed or sustained attack — use Cloud Armor / API
  Gateway for that if this service becomes a real target.
- **The 50KB body-size check relies on the `Content-Length` header** and
  will not catch a chunked-encoded request that omits it. Combine with a
  platform-level request size limit (e.g. a Cloud Armor policy or Cloud Run's
  own request size ceiling) for a stronger guarantee.
- Never log `financial_context` contents or the OpenAI API key. Current
  logging only records high-level events (endpoint hit, error class,
  latency).
