---
name: agent-login
description: Authenticate a browser/QA agent against the current project's running app. Use before any QA, Playwright, smoke, or e2e work that needs an authenticated session. Dispatches to the project's own login skill or AGENTS.md § Agent Login for project specifics.
---

# Agent Login (Dispatcher)

Login flows genuinely differ per project (seeded credentials with dev-log OTPs, social/OAuth providers, mock-auth toggles, service-agent credentials, ...). This skill does not encode any project's flow. It resolves the correct flow, then applies the universal rules below.

## Resolution Order

1. **Project-level skill.** If the project defines its own `agent-login` skill (e.g. under `.claude/skills/agent-login/` or `.opencode/skills/agent-login/`), defer to it entirely. It is authoritative for URLs, credentials, selectors, and flow.

2. **AGENTS.md § Agent Login.** Otherwise, read the repository's `AGENTS.md` section "Agent Login" and follow it. Per the harness contract it specifies: target URLs, auth mechanism, test credentials or seeding procedure, storage-state locations, MFA/OTP handling in non-prod, and what must never be captured.

3. **Neither exists.** Stop and report that the project has no agent-login guidance. Do not guess URLs, invent credentials, or attempt logins against discovered endpoints.

## Universal Rules (apply regardless of which source resolved)

### Environment selection

- QA agents target the project's staging/dev environment by default, per AGENTS.md § Environments.
- **Never use production for QA logins unless the user explicitly instructs it** (e.g. an explicit production smoke pass).
- Avoid pointing QA at a developer's locally running dev server unless the user asks; it clashes with their session and tests the wrong environment. When local services must be configured, prefer `127.0.0.1` over `localhost` where host/cookie sensitivity matters.
- Do not log in at all when validating public/unauthenticated pages; test them directly.

### Prefer non-interactive session establishment

In order of preference:

1. **Saved storage states**: reuse Playwright storage-state files the project's e2e harness generates (locations per the resolved source).
2. **E2E harness seeding**: run the project's e2e setup so it seeds deterministic accounts and logs in through the real login page for you.
3. **Mock/service-agent auth**: only when the resolved source documents it and the user confirms it is configured for the target environment.
4. **Manual UI login**: last resort, using only credentials the resolved source or the user provides. Never invent credentials; if none are available, stop and ask.

### Verifying a login succeeded

- Wait for an authenticated layout element or authenticated route defined by the resolved source (e.g. a primary-navigation landmark, or redirect to the app shell/console/onboarding route). Do not treat the absence of an error message as success.
- If MFA/OTP is involved in non-prod, use the project's documented dev delivery mechanism (e.g. OTPs written to a backend log). Never trigger real SMS/email delivery for QA unless instructed.

### Secret hygiene (strict)

- Never capture or paste JWTs, refresh tokens, session cookies, OTPs, passwords, client secrets, raw auth headers, API keys, or PII into GitHub issues, PR comments, chat summaries, logs, or screenshots.
- Crop or redact screenshots that show tokens, emails, or personal/financial data.
- Redact emails unless they are test-only addresses; use test-only accounts in issue reproductions when possible.
- Seeded e2e credentials belong to throwaway e2e databases; do not assume they exist elsewhere.

## If Login Fails

Before filing a bug, verify:

- The target URL matches the app under test and the intended environment.
- The test account exists in that environment's database (has the seed run there?).
- The browser is not already authenticated as another user; start a fresh browser context or clear storage.
- The backend/API is reachable from the frontend's configured API URL.
- Auth-provider configuration matches the environment (callback URLs, provider enabled, mock/service-agent variables set on both frontend and backend where applicable).
- MFA users have a working non-prod delivery mechanism configured.

File a bug only after the failure is reproducible with a known account and a clear expected result; with all secrets redacted.
