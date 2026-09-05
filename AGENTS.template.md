# AGENTS.md Harness Contract

Every project that uses the shared (user-level) harness skills MUST provide an
`AGENTS.md` at the repository root containing the sections below, with these
exact headings. The shared skills contain no project facts; they resolve
everything through these sections at runtime. If a section is missing, the
skill should say so and stop rather than guess.

Claude Code note: the project must also have a `CLAUDE.md` whose first line is
`@AGENTS.md` so the contract is loaded there too.

**Static vs. detail files.** AGENTS.md is static context; every token is
loaded into every session, whatever the task. Keep it lean. Sections that
nearly every task needs (Project Overview, Code Layout & Tech Stack, Build &
Validation, Project Board, Repositories, Environments, Branch Map) stay
inline. Sections consumed by a single workflow (CI Pipeline, Review Notes,
the detail of Agent Login) should be a few summary lines plus a pointer to a
detail file under `Docs/agents/` (e.g. `Docs/agents/ci-pipeline.md`), which
the relevant skill loads on demand. A skill reading a section that names a
detail file MUST read that file before acting on the section.

---

## Project Overview

One or two paragraphs: what the product is, who uses it, current phase.

## Code Layout & Tech Stack

Where the backend/frontend/tests live, the language/framework versions, and
the architectural conventions reviewers must enforce (error-handling style,
ID scheme, layer boundaries, etc.).

## Build & Validation

The exact commands agents run to build, test, lint, and format each part of
the codebase, plus:

- **DB tripwire files**: the list of files that, when touched, require the
  live-database integration suite to run before a PR is opened or merged.

## Project Board

- Owner/org and project number (e.g. `orgs/<org>/projects/<n>`)
- The Status field's option names in lifecycle order
  (e.g. `Backlog → Ready → In progress → In review → Done`)
- Skills must look up field/option IDs live via `gh project field-list`;
  never record IDs here.

## Repositories

- App repo slug (e.g. `org/app`)
- Deployment repo slug and its local sibling path, if one exists
- Issue template path (e.g. `.github/ISSUE_TEMPLATE/issue.md`)

## Environments

For each environment (dev/staging/prod): URL, cluster/context name,
namespace, and the Docker image names published for it.

## Branch Map

Which branch integrates to which environment, and which CI workflow file
each branch/PR triggers (e.g. `main → staging via develop.yaml`,
`prod → production via prod.yaml`, `PR → validate.yaml`). This is the single
source of truth for base branches in dev-cycle/code-review.

## Agent Login

How a browser/QA agent authenticates against a running instance. This section
is the contract every consuming project keeps; the shared harness no longer
ships a generic `agent-login` skill, so this section is the floor.

**Project-specific (fill in):** target URLs, auth mechanism, test credentials
or seeding procedure, storage-state locations, MFA/OTP handling in non-prod,
and what must never be captured in issues or logs. Projects with complex flows
may keep a project-level `agent-login` skill and point to it from here; when
that skill exists it is authoritative.

**Universal rules (required floor; applies even when a project-level `agent-login`
skill exists):**

- Target the project's staging/dev environment by default. Never use
  production for QA logins unless the user explicitly instructs it.
- Prefer non-interactive session establishment in this order: saved Playwright
  storage-state files produced by the project's e2e harness, the project's
  e2e setup seeding accounts, mock/service-agent auth where this section
  documents it and the user has confirmed it is configured, manual UI login
  last.
- Verify login success by an authenticated layout element or route this
  section names; absence of an error is not success.
- Never capture or paste JWTs, refresh tokens, session cookies, OTPs,
  passwords, client secrets, API keys, raw auth headers, or PII into GitHub
  issues, PR comments, chat summaries, logs, or screenshots. Redact
  screenshots that show tokens or personal data.
- Seeded e2e credentials belong to throwaway e2e databases and must not be
  assumed to exist in any other environment.
- When host/cookie sensitivity matters, prefer `127.0.0.1` over `localhost`
  in host-side config.
- If a required field above is not documented and credentials are not
  available from the user, stop and report that this project has no
  agent-login guidance; do not invent credentials, URLs, or flows.

## Review Notes

Project-specific review guidance layered on top of the shared checklist:
known existing bugs reviewers should flag interactions with, extra checks,
and areas of the codebase under active migration (with what supersedes what).

## CI Pipeline (optional)

Job names, expected durations, and polling guidance for the deploy monitor.
If absent, the deploy skill falls back to `gh run watch` with a generic
polling cadence.
