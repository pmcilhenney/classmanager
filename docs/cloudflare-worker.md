# Cloudflare Worker Setup

The Git-linked Cloudflare deploy runs `npx wrangler deploy`, so the committed `wrangler.toml` is the deploy source of truth.

`scripts/cf-bootstrap.sh` still exists for local/manual setup: it creates or reuses the D1 database and R2 bucket, writes `wrangler.generated.jsonc` with the resolved D1 ID, and applies migrations.

## One-time Bootstrap

```bash
npm install
npm run cf:bootstrap
```

The bootstrap script:

1. Confirms Wrangler is authenticated.
2. Creates or reuses the D1 database named `classmanager-db`.
3. Creates or reuses the R2 bucket named `classmanager-artifacts`.
4. Writes `wrangler.generated.jsonc` with the real D1 database ID and R2 bucket name.
5. Applies D1 migrations from `worker/migrations`.

Deploy after secrets are added:

```bash
npm run cf:deploy
```

Override default resource names when needed:

```bash
WORKER_NAME=classmanager-api \
D1_NAME=classmanager-db \
D1_LOCATION=enam \
R2_BUCKET=classmanager-artifacts \
npm run cf:bootstrap
```

## Required Secrets

Set these after `npm run cf:bootstrap` has generated `wrangler.generated.jsonc`:

```bash
printf 'your-jotform-api-key' | npx wrangler secret put JOTFORM_API_KEY -c wrangler.toml
printf 'your-flexiquiz-api-key' | npx wrangler secret put FLEXIQUIZ_API_KEY -c wrangler.toml
printf 'your-flexiquiz-sso-shared-secret' | npx wrangler secret put FLEXIQUIZ_SSO_SHARED_SECRET -c wrangler.toml

printf 'smartermail-username-or-email' | npx wrangler secret put SM_USERNAME -c wrangler.toml
printf 'smartermail-password' | npx wrangler secret put SM_PASSWORD -c wrangler.toml
printf 'sender@example.org' | npx wrangler secret put FROM_ADDRESS -c wrangler.toml
printf 'reply-to@example.org' | npx wrangler secret put REPLY_TO_ADDRESS -c wrangler.toml
```

`SM_BASE_URL`, `SM_AUTH`, and `SM_SEND_EMAIL` are non-secret defaults in `wrangler.template.jsonc`.

## Current Worker Surface

- `GET /health`
- `POST /session/lookup`
- `GET /progress/:classSessionId/:studentId`
- `PATCH /progress/:classSessionId/:studentId`
- `POST /quiz/assign`
- `GET /quiz/review/:attemptId`
- `POST /email/send`

The initial Worker is intentionally a deployable backing skeleton. Jotform normalization, full FlexiQuiz lookup/create/assign, and native Swift API client wiring are the next implementation slices.
