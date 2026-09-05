---
name: qa
description: QA a running app through the Playwright MCP like a careful human tester; reproduce bugs with evidence and file only deterministic ones via issue-raise. Use when asked to QA, smoke test, regression test, explore the app, or verify a workflow.
---

# QA

Project facts from `AGENTS.md`: **§ Environments** (target URL), **§ Agent Login** (auth flow, credentials, what must never be captured; any project-level `agent-login` skill it names is authoritative), **§ Repositories**, **§ Project Board**. Missing section: name it and stop.

Target: staging from § Environments by default; a local URL only when the user says the app is running locally and confirms it; production only when the user explicitly asks for a production smoke pass.

## Rules

- All browser interaction through the Playwright MCP `browser_*` tools; never author test scripts, spec files, or `node -e` snippets, never `npx playwright`, never `browser_run_code_unsafe`. `browser_evaluate` only to read state a snapshot cannot express.
- Touch source only when a test genuinely requires it.
- File only what you reproduced; no speculative concerns, style preferences, or future enhancements. Search open and closed issues first; never duplicate.
- Never put secrets, tokens, cookies, OTPs, passwords, API keys, raw auth headers, PII, or customer data into issues, chat, logs, or screenshots; redact before filing.

## Login

- Establish a session non-interactively where possible, in this order: saved storage-state files from the project's e2e harness; the e2e setup's seeded accounts; mock/service-agent auth where § Agent Login documents it and the user confirmed it is configured; manual UI login last.
- Verify login by the authenticated element or route § Agent Login names; absence of an error is not success.
- Seeded e2e credentials exist only in throwaway e2e databases. Mock auth is never enabled outside local development. Prefer `127.0.0.1` over `localhost` when cookie/host sensitivity matters.
- If § Agent Login does not document what a workflow needs and the user supplies nothing, stop and report; never invent credentials, URLs, or flows.

Ask only when missing and required: the app URL (no staging URL anywhere), the test account/role, the workflow focus beyond a smoke pass.

## Workflow

1. **Context.** Read `AGENTS.md` and relevant docs; resolve login; read the issue template; confirm the repo (`gh repo view --json owner,name`); load labels and Issue Types (`gh label list`, the GraphQL query in `issue-raise`); search existing issues for the area.
2. **Browser.** `browser_navigate` to the target (session persists). Read with `browser_snapshot` for element refs (or `browser_find` when large); act with `browser_click` / `browser_type` / `browser_fill_form` / `browser_press_key` / `browser_hover` / `browser_select_option`; settle with `browser_wait_for`, not sleeps. Capture evidence as you go: `browser_take_screenshot`, `browser_console_messages`, `browser_network_requests`. If the MCP exposes tracing or storage-state tools, use them for traces and role isolation; otherwise start each role from a clean context (`browser_close`, re-navigate, re-authenticate). Record the URL, role, browser, timestamp, seed data.
3. **Explore** like a user: primary happy path, then obvious edge paths. Watch auth redirects, permission and data-isolation boundaries, validation, loading states, stale data, failed requests, inaccessible controls, console errors, uploads/downloads, route-level 404/500s. Verify before/after state rather than trusting UI copy.
4. **Reproduce** before filing: deterministic steps and the same incorrect result again after a reload or fresh navigation, with evidence (error text, console error, failed request, screenshot path, observed state). A one-off is an observation, not an issue.
5. **File** via `issue-raise` (it owns template, Type, labels, assignee, board): Type `Bug` when enabled, existing labels (prefer `bug`), the new-issue status. Body: tested role, URL, browser, timestamp, numbered steps, actual vs expected, evidence paths, suspected area, related issues checked, and the merged PR/issue it traces to when found by a batch sweep. One issue per root cause.
6. **Report**: workflows tested; issues created (URLs); reproducible bugs not filed and why; non-reproducible observations; validation limits (pages not reached, credentials missing, services unavailable).
