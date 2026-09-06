# AGENTS.md Harness Contract

Projects using shared user-level skills MUST provide root `AGENTS.md` with
the exact section headings below. Skills resolve project facts there at runtime.

**Missing-section rule (every skill):** name the section and stop if it is
missing or insufficient. Never guess project facts.

For Claude Code, also provide `CLAUDE.md` with first line `@AGENTS.md`.

**Keep it lean:** `AGENTS.md` loads every session. Keep common guidance inline;
summarize workflow-specific detail (Review Notes, Agent Login) and link
`Docs/agents/` files, which skills must read before acting.

## Harness conventions the project must accommodate

Fixed by shared skills, not per-project choices:

- **Body is the What, ledger is the How.** Issue bodies hold the durable spec
  (summary, context, expected outcome, notes/constraints), never designs or task
  checklists. Approach, touch points, validation, risks, and execution tasks
  belong in exactly one issue comment whose first line is
  `<!-- plan-ledger -->`.
- **Worktrees:** root `.worktrees/`; multi-line GitHub body staging: root
  `.tmp-*` files. Both patterns must be in `.gitignore`.
- **Docs paths:** `weekly-review` writes to `Docs/status/`; workflow details live in `Docs/agents/`.
  Batch state belongs only on the board and issue comments, never in project files.
- **Ownership:** with a board, claim only ready -> in-progress; with `board: none`, use `issue-plan`'s ledger/tie-break. Existing ledgers still require authorized resume.

---

## Project Overview

One or two paragraphs: what the product is, who uses it, current phase.

## Code Layout & Tech Stack

Backend/frontend/test locations, language/framework versions, and enforced
architecture (error handling, ID scheme, layer boundaries). Include applicable
migration conventions and new-file build-order registration (e.g. compile lists).

## Build & Validation

Exact build, test, lint, and format commands for each codebase part, plus:

- **DB tripwire files**: files whose changes require live-database integration
  tests before opening or merging a PR; `none` if no database layer.
- **Commit message convention**: one-line style rule. Default if absent:
  single-line imperative subject under 72 characters matching recent history.

## Project Board

Declare `none`, or provide all configured-board facts below:

- Owner/org and project number (e.g. `orgs/<org>/projects/<n>`).
- Status option names in lifecycle order, identifying backlog (un-refined),
  ready, in-progress, in-review, and done.
- **New-issue status**: destination for newly filed issues (usually backlog).
- **Done automation**: whether GitHub's "item closed" workflow moves closed
  issues to done; otherwise the merging skill must do so.
- Look up field/option IDs live via `gh project field-list`; never record them.
  For a missing `gh project` scope, run
  `gh auth refresh --hostname github.com -s project`.

## Repositories

- App repo slug (e.g. `org/app`)
- Deployment repo slug, if `weekly-review` should report its pipeline runs
- Issue template path (e.g. `.github/ISSUE_TEMPLATE/issue.md`)

## Environments

Running environment URLs (dev/staging/prod) for `qa` and `burndown` QA sweeps,
including the default QA target; `none` if absent. Deployment is outside the
shared harness: keep mechanics in a project-level skill or detail file.

## Branch Map

Branch-to-environment and branch/PR-to-CI-workflow-file mappings. This is the
base-branch authority for issue-implement/code-review. State whether integration
merges auto-deploy; reviewer auto-merge and burndown QA depend on it.

## Agent Login

Authentication for running-instance `qa` and local `setup`: target URLs,
mechanism, test credentials or seeding, storage-state locations, non-prod
MFA/OTP, authenticated proof element/route, local mock-auth flags, and facts
forbidden in issues/logs. Summarize complex flows and link
`Docs/agents/agent-login.md` or a project-level `agent-login` skill; that skill
is authoritative when present.

Do not restate shared `qa` login rules: staging default, non-interactive
session order, authenticated-element verification, no token/PII capture,
local-only mock auth, and stopping rather than inventing credentials.

## Review Notes

Layer project guidance over shared stack-neutral `code-review/checklist.md`:
idioms, formatting, known-bug interactions, extra checks, and active migrations
(including replacements). Link stack-specific checklists, e.g.
`Docs/agents/review-checklist.md`.
