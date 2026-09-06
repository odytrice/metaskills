---
name: qa
description: Test a running app through Playwright MCP and file reproduced bugs. Use for QA, smoke/regression testing, app exploration, or workflow verification.
---

# QA

Project facts from `AGENTS.md`: **§ Environments** (target URL), **§ Agent Login** (auth flow, credentials, what must never be captured; any project-level `agent-login` skill it names is authoritative), **§ Repositories**, **§ Project Board**. Missing section: name it and stop.

Explicit `board: none` is valid per `issue-plan` § Board Status Transitions; file confirmed bugs without board operations and report it. Missing board facts still stop.

Target: documented staging by default; local only with user-confirmed running app/URL; production only for an explicitly requested production smoke pass.

## Rules

- Use only Playwright MCP `browser_*` tools: no test scripts/specs, `node -e`, `npx playwright`, or `browser_run_code_unsafe`. `browser_evaluate` may only read state snapshots cannot express.
- Touch source only when a test genuinely requires it.
- File reproduced bugs only, not speculation, style, or enhancements. Search open/closed issues first; never duplicate.
- Never put secrets, tokens, cookies, OTPs, passwords, API keys, raw auth headers, PII, or customer data into issues, chat, logs, or screenshots; redact before filing.

## Login

- Prefer non-interactive login, in order: e2e saved storage-state; seeded e2e accounts; documented, user-confirmed configured mock/service-agent auth; manual UI login last.
- Verify the authenticated element/route in § Agent Login; no error is not success.
- Seeded credentials work only in throwaway e2e databases; mock auth only in local development. Prefer `127.0.0.1` for cookie/host sensitivity.
- Required login facts undocumented and unsupplied: stop and report; never invent credentials, URLs, or flows.

Ask only for missing required URL (no documented staging), account/role, or focus beyond smoke testing.

## Workflow

1. **Context.** Read `AGENTS.md`, relevant docs and issue template; resolve login; confirm repo (`gh repo view --json owner,name`); load labels/Types (`gh label list`, `issue-raise` GraphQL query); search related issues.
2. **Browser.** `browser_navigate` preserves session. Get refs with `browser_snapshot` (`browser_find` for large pages); use click/type/fill/key/hover/select tools. Settle with `browser_wait_for`, never sleeps. Capture `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests` evidence. Use tracing/storage-state tools if exposed for traces/role isolation; otherwise clean each role via `browser_close`, re-navigation, re-authentication. Record URL, role, browser, timestamp, seed data.
3. **Explore** happy then edge paths: auth redirects, permissions/data isolation, validation, loading/stale data, failed requests, inaccessible controls, console errors, uploads/downloads, route 404/500s. Verify before/after state, not UI claims.
4. **Reproduce** deterministic steps with the same failure after reload/fresh navigation. Capture error text, console errors, failed requests, screenshot paths, or observed state. One-offs are observations, not issues.
5. **File** via `issue-raise`, which owns template/Type/labels/assignee/board: enabled Type `Bug`, existing labels (prefer `bug`), new-issue status. Include role, URL, browser, timestamp, numbered steps, actual/expected, evidence paths, suspected area, related issues checked, and originating merged PR/issue for batch sweeps. One issue per root cause.
6. **Report** workflows, issue URLs, unfiled reproducible bugs/reasons, non-reproducible observations, and limits (unreached pages, missing credentials, unavailable services).
