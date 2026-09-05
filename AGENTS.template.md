# AGENTS.md Harness Contract

Every project that uses the shared (user-level) harness skills MUST provide an
`AGENTS.md` at the repository root containing the sections below, with these
exact headings. The shared skills contain no project facts; they resolve
everything through these sections at runtime.

**Missing-section rule (applies to every skill):** if a section a skill needs
is missing or does not answer the question, the skill names the section and
stops. It never guesses a project fact.

Claude Code note: the project must also have a `CLAUDE.md` whose first line is
`@AGENTS.md` so the contract is loaded there too.

**Keep it lean.** Every token of AGENTS.md is loaded into every session.
Sections nearly every task needs stay inline; sections one workflow consumes
(Review Notes, Agent Login detail) are a few summary lines plus
a pointer to a detail file under `Docs/agents/`, which the skill reads before
acting on the section.

## Harness conventions the project must accommodate

These are fixed by the shared skills, not chosen per project:

- **Body is the What, ledger is the How.** An issue body is the durable spec
  (summary, context, expected outcome, notes/constraints) and never carries a
  design or task checklist. The approach, touch points, validation, risks, and
  execution tasks live in exactly one issue comment whose first line is
  `<!-- plan-ledger -->`.
- **Worktrees** are created under `.worktrees/` at the repo root; skills stage
  multi-line GitHub bodies in `.tmp-*` files at the repo root. Both patterns
  must be in the project's `.gitignore`.
- **Docs paths.** Skills write batch ledgers to `Docs/plans/`, status reports
  to `Docs/status/`, and read workflow detail files from `Docs/agents/`.
- **Board Status is the claim lock.** Moving an item out of the ready status
  into the in-progress status is the claim; skills only claim from ready.

---

## Project Overview

One or two paragraphs: what the product is, who uses it, current phase.

## Code Layout & Tech Stack

Where the backend/frontend/tests live, the language/framework versions, and
the architectural conventions reviewers must enforce (error-handling style,
ID scheme, layer boundaries, etc.). Include the project's migration convention
and any build-order registration a new file needs (e.g. an explicit compile
list), if either applies.

## Build & Validation

The exact commands agents run to build, test, lint, and format each part of
the codebase, plus:

- **DB tripwire files**: the list of files that, when touched, require the
  live-database integration suite to run before a PR is opened or merged
  (state `none` if there is no database layer).
- **Commit message convention**: one line describing the style (e.g.
  "single-line, lowercase imperative, no trailing period, under 72 chars").
  If absent, skills default to a single-line imperative subject under 72
  characters matching recent history.

## Project Board

- Owner/org and project number (e.g. `orgs/<org>/projects/<n>`), or `none`.
- The Status field's option names in lifecycle order
  (e.g. `Backlog → Ready → In progress → In review → Done`), naming which is
  the backlog (un-refined), ready, in-progress, in-review, and done status.
- **New-issue status**: the option newly filed issues are placed in (usually
  the backlog status).
- **Done automation**: whether the board moves items to the done status
  automatically when the issue closes (GitHub's built-in "item closed"
  workflow). If not, the skill that merges a PR sets the done status itself.
- Skills must look up field/option IDs live via `gh project field-list`;
  never record IDs here. If `gh project` reports a missing scope, the fix is
  `gh auth refresh --hostname github.com -s project`.

## Repositories

- App repo slug (e.g. `org/app`)
- Deployment repo slug, if `weekly-review` should report its pipeline runs
- Issue template path (e.g. `.github/ISSUE_TEMPLATE/issue.md`)

## Environments

The URL of each running environment (dev/staging/prod) that `qa` and the
`burndown` QA sweep may target, and which one is the default QA target.
Deployment itself is project-specific and outside the shared harness; keep
its mechanics in a project-level skill or detail file. State `none` if the
project has no running environments.

## Branch Map

Which branch integrates to which environment, and which CI workflow file
each branch/PR triggers (e.g. `main → staging via develop.yaml`,
`prod → production via prod.yaml`, `PR → validate.yaml`). This is the single
source of truth for base branches in issue-implement/code-review. Note whether
merging the integration branch auto-deploys, since the reviewer's auto-merge
and the burndown QA sweep both depend on it.

## Agent Login

How a browser/QA agent authenticates against a running instance (for the
`qa` skill) and how local development auth is wired (for `setup`): target
URLs, auth mechanism, test credentials or seeding procedure, storage-state
locations, MFA/OTP handling in non-prod, the authenticated element or route
that proves login, local mock-auth flags, and anything project-specific that
must never be captured in issues or logs. Keep it to a few lines plus a
pointer to `Docs/agents/agent-login.md` or a project-level `agent-login`
skill for complex flows; when that skill exists it is authoritative.

The universal login rules (staging by default, non-interactive session order,
verify by an authenticated element, never capture tokens or PII, mock auth
only in local development, stop rather than invent credentials) live in the
shared `qa` skill and apply to every project; do not restate them here.

## Review Notes

Project-specific review guidance layered on top of the shared, stack-neutral
`code-review/checklist.md`: the stack's idioms and formatting rules, known
existing bugs reviewers should flag interactions with, extra checks, and
areas of the codebase under active migration (with what supersedes what).
Stack-specific checklists belong in a detail file this section points to
(e.g. `Docs/agents/review-checklist.md`).
